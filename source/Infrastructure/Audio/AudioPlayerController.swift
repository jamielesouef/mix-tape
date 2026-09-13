//  AudioPlayerController.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import AVFoundation
import Foundation
import MediaPlayer
import UIKit

final class AudioPlayerController: AudioPlayerControlling {
    var onPositionChange: ((Duration) -> Void)?
    var onEnded: (() -> Void)?
    var onFailure: ((MixtapeError) -> Void)?
    var onRemotePlay: (() -> Void)?
    var onRemotePause: (() -> Void)?
    var onRemoteNext: (() -> Void)?
    var onRemotePrevious: (() -> Void)?
    var onRemoteSeek: ((Duration) -> Void)?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: (any NSObjectProtocol)?
    private var statusObservation: NSKeyValueObservation?
    private var interruptionObserver: (any NSObjectProtocol)?
    private var routeChangeObserver: (any NSObjectProtocol)?
    private var mediaResetObserver: (any NSObjectProtocol)?
    private var didConfigureSession = false
    private var lastLoadedURL: URL?

    init() {
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

    func load(url: URL) {
        configureSessionIfNeeded()

        lastLoadedURL = url
        removeItemObservers()

        let asset = AVURLAsset(
            url: url,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        )
        let item = AVPlayerItem(asset: asset)

        player.replaceCurrentItem(with: item)

        observePosition()
        observeEnd(of: item)
        observeFailure(of: item)
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(to position: Duration) {
        player.seek(to: CMTime(
            seconds: Double(position.components.seconds),
            preferredTimescale: Self.timescale
        ))
    }

    func stop() {
        removeItemObservers()

        player.pause()
        player.replaceCurrentItem(with: nil)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func updateNowPlaying(_ info: NowPlayingInfo) {
        var entries: [String: Any] = [
            MPMediaItemPropertyTitle: info.title,
            MPMediaItemPropertyArtist: info.artist,
            MPMediaItemPropertyAlbumTitle: info.albumTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: Double(info.position.components.seconds),
            MPNowPlayingInfoPropertyPlaybackRate: info.isPlaying ? 1.0 : 0.0
        ]

        if let duration = info.duration {
            entries[MPMediaItemPropertyPlaybackDuration] = Double(duration.components.seconds)
        }

        if let artwork = info.artwork {
            entries[MPMediaItemPropertyArtwork] = Self.makeArtwork(artwork)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = entries
    }

    func setNextTrackEnabled(_ enabled: Bool) {
        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = enabled
    }

    // MARK: - Private

    private static let timescale: CMTimeScale = 600
    private static let positionInterval = CMTime(seconds: 1, preferredTimescale: timescale)

    private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    private func configureSessionIfNeeded() {
        guard didConfigureSession == false else {
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)

            didConfigureSession = true

            AppLogger.playback.info("audio session configured: category .playback, active")
        } catch {
            AppLogger.playback
                .error("audio session configuration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Item observers

    private func observePosition() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: Self.positionInterval,
            queue: .main
        ) { [weak self] time in
            let seconds = time.seconds.isFinite ? time.seconds : 0

            MainActor.assumeIsolated {
                self?.onPositionChange?(.seconds(seconds))
            }
        }
    }

    private func observeEnd(of item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onEnded?()
            }
        }
    }

    private func observeFailure(of item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else {
                return
            }

            let message = item.error?.localizedDescription ?? "Audio playback failed"

            Task { @MainActor in
                self?.onFailure?(.transport(message))
            }
        }
    }

    private func removeItemObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }

        timeObserver = nil
        endObserver = nil
        statusObservation = nil
    }

    // MARK: - Audio session observers

    private func configureSessionObservers() {
        let center = NotificationCenter.default

        observeInterruptions(on: center)
        observeRouteChanges(on: center)
        observeMediaServicesReset(on: center)

        AppLogger.playback
            .info("audio session interruption/route-change/reset observers registered")
    }

    private func observeInterruptions(on center: NotificationCenter) {
        interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let userInfo = notification.userInfo

            guard let typeValue = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else {
                return
            }

            let optionsValue = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0

            MainActor.assumeIsolated {
                self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
            }
        }
    }

    private func observeRouteChanges(on center: NotificationCenter) {
        routeChangeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let reasonKey = AVAudioSessionRouteChangeReasonKey

            guard let reasonValue = notification.userInfo?[reasonKey] as? UInt else {
                return
            }

            MainActor.assumeIsolated {
                self?.handleRouteChange(reasonValue: reasonValue)
            }
        }
    }

    private func observeMediaServicesReset(on center: NotificationCenter) {
        mediaResetObserver = center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMediaServicesReset()
            }
        }
    }

    // MARK: - Audio session handlers

    private func handleInterruption(typeValue: UInt, optionsValue: UInt) {
        guard let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

        switch audioInterruptionAction(type: type, options: options) {
        case .pause: onRemotePause?()
        case .resume: onRemotePlay?()
        case .none: break
        }
    }

    private func handleRouteChange(reasonValue: UInt) {
        guard
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
            reason == .oldDeviceUnavailable
        else {
            return
        }

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

    // MARK: - Remote commands

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            self?.onRemotePlay?()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            self?.onRemotePause?()
            return .success
        }

        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onRemoteNext?()
            return .success
        }

        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.onRemotePrevious?()
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }

            self?.onRemoteSeek?(.seconds(event.positionTime))
            return .success
        }
    }
}
