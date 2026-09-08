//  AudioPlayerController.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import AVFoundation
import Foundation
import MediaPlayer
import MixtapeDomain
import UIKit

/// `AVPlayer`-backed audio with `AVAudioSession .playback`, `MPRemoteCommandCenter` and
/// `MPNowPlayingInfoCenter` (engineering doc §7). Background audio is on via the app's
/// `UIBackgroundModes` key.
public final class AudioPlayerController: AudioPlayerControlling {
    public var onPositionChange: ((Duration) -> Void)?
    public var onEnded: (() -> Void)?
    public var onFailure: ((MixtapeError) -> Void)?
    public var onRemotePlay: (() -> Void)?
    public var onRemotePause: (() -> Void)?
    public var onRemoteNext: (() -> Void)?
    public var onRemotePrevious: (() -> Void)?
    public var onRemoteSeek: ((Duration) -> Void)?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: (any NSObjectProtocol)?
    private var statusObservation: NSKeyValueObservation?
    private var interruptionObserver: (any NSObjectProtocol)?
    private var routeChangeObserver: (any NSObjectProtocol)?
    private var mediaResetObserver: (any NSObjectProtocol)?
    private var didConfigureSession = false
    /// So a media-services reset (below) can reload what was playing; never read for anything else.
    private var lastLoadedURL: URL?

    public init() {
        configureRemoteCommands()
        configureSessionObservers()
    }

    isolated deinit {
        for observer in [interruptionObserver, routeChangeObserver, mediaResetObserver] {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    public func load(url: URL) {
        configureSessionIfNeeded()
        lastLoadedURL = url
        removeItemObservers()
        // Precise timing is opted in (slice 018, Triage 7 v2): AVFoundation otherwise estimates a FLAC
        // seek target by bitrate and its clock drifts from the audio it decodes — a seek near the end
        // of a long FLAC never reaches `didPlayToEndTime` on macOS and fails the item on iOS.
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let item = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: item)
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.onPositionChange?(.seconds(time.seconds.isFinite ? time.seconds : 0))
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onEnded?()
            }
        }
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let message = item.error?.localizedDescription ?? "Audio playback failed"
            Task { @MainActor in
                self?.onFailure?(.transport(message))
            }
        }
    }

    public func play() {
        player.play()
    }

    public func pause() {
        player.pause()
    }

    public func seek(to position: Duration) {
        player.seek(to: CMTime(seconds: Double(position.components.seconds), preferredTimescale: 600))
    }

    public func stop() {
        removeItemObservers()
        player.pause()
        player.replaceCurrentItem(with: nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    public func updateNowPlaying(_ info: NowPlayingInfo) {
        var now: [String: Any] = [
            MPMediaItemPropertyTitle: info.title,
            MPMediaItemPropertyArtist: info.artist,
            MPMediaItemPropertyAlbumTitle: info.albumTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(info.position.components.seconds),
            MPNowPlayingInfoPropertyPlaybackRate: info.isPlaying ? 1.0 : 0.0,
        ]
        if let duration = info.duration {
            now[MPMediaItemPropertyPlaybackDuration] = Double(duration.components.seconds)
        }
        if let artwork = info.artwork {
            now[MPMediaItemPropertyArtwork] = Self.makeArtwork(artwork)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = now
    }

    public func setNextTrackEnabled(_ enabled: Bool) {
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = enabled
    }

    // MARK: - Private

    /// The artwork request handler is called by the system off the main thread, so it must be
    /// built in a `nonisolated` context or it traps under the project's MainActor default isolation
    /// (same class of trap decision 44 records for VLC).
    private nonisolated static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func configureSessionIfNeeded() {
        guard didConfigureSession == false else { return }
        // Marked done only once both calls succeed, so one transient failure does not end every
        // later attempt (slice 019).
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            didConfigureSession = true
            AppLogger.playback.info("audio session configured: category .playback, active")
        } catch {
            AppLogger.playback.error("audio session configuration failed: \(error.localizedDescription)")
        }
    }

    /// Interruptions (phone call, another app's audio), route changes (headphones unplugged) and a
    /// media-services reset all route through the existing pause/resume seam — `onRemotePause`/
    /// `onRemotePlay` — rather than a new callback pair (slice 023 decision log): the service reacts
    /// to a player that stopped for a reason outside the app exactly as it does to a remote command.
    private func configureSessionObservers() {
        let center = NotificationCenter.default
        // `Notification` isn't `Sendable`, so each closure reads its `userInfo` here — outside the
        // isolated block below — and only the extracted, `Sendable` raw values cross into it.
        interruptionObserver = center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            MainActor.assumeIsolated { // the system posts this notification on the main thread
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
        routeChangeObserver = center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
            MainActor.assumeIsolated { // posted on a secondary thread; `queue: .main` marshals it here
                self?.handleRouteChange(reasonValue: reasonValue)
            }
        }
        mediaResetObserver = center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { // the system posts this notification on the main thread
                self?.handleMediaServicesReset()
            }
        }
        AppLogger.playback.info("audio session interruption/route-change/reset observers registered")
    }

    private func handleInterruption(typeValue: UInt, optionsValue: UInt) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        switch audioInterruptionAction(type: type, options: options) {
        case .pause: onRemotePause?()
        case .resume: onRemotePlay?()
        case .none: break
        }
    }

    /// Headphones/speaker unplugged mid-playback pauses, matching system convention for media apps.
    private func handleRouteChange(reasonValue: UInt) {
        guard let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue), reason == .oldDeviceUnavailable else { return }
        onRemotePause?()
    }

    /// Apple's guidance for this notification: reinitialise audio objects and the session
    /// configuration, but never restart playback except on user action — so this reloads whatever
    /// was loaded, and never calls `play()`.
    private func handleMediaServicesReset() {
        didConfigureSession = false
        AppLogger.playback.error("media services reset; reconfiguring audio session")
        guard let lastLoadedURL else {
            configureSessionIfNeeded()
            return
        }
        load(url: lastLoadedURL)
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in self?.onRemotePlay?(); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.onRemotePause?(); return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in self?.onRemoteNext?(); return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.onRemotePrevious?(); return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.onRemoteSeek?(.seconds(event.positionTime))
            return .success
        }
    }

    private func removeItemObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        statusObservation = nil
    }
}
