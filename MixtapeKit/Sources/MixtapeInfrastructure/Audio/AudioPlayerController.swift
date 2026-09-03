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
    private var didConfigureSession = false

    public init() {
        configureRemoteCommands()
    }

    public func load(url: URL) {
        configureSessionIfNeeded()
        removeItemObservers()
        let item = AVPlayerItem(url: url)
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
        didConfigureSession = true
        #if os(iOS) || os(tvOS)
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
        #endif
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
