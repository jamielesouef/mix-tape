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

    private nonisolated static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func configureSessionIfNeeded() {
        guard didConfigureSession == false else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            didConfigureSession = true
            AppLogger.playback.info("audio session configured: category .playback, active")
        } catch {
            AppLogger.playback.error("audio session configuration failed: \(error.localizedDescription)")
        }
    }

    private func configureSessionObservers() {
        let center = NotificationCenter.default
        interruptionObserver = center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            MainActor.assumeIsolated {
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
        routeChangeObserver = center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
            MainActor.assumeIsolated {
                self?.handleRouteChange(reasonValue: reasonValue)
            }
        }
        mediaResetObserver = center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
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

    private func handleRouteChange(reasonValue: UInt) {
        guard let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue), reason == .oldDeviceUnavailable else { return }
        onRemotePause?()
    }

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
