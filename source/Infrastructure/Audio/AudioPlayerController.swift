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
    private var lastLoadedURL: URL?

    private let audioSession = AudioSessionCoordinator()
    private let remoteCommands = RemoteCommandCenter()

    init() {
        remoteCommands.onPlay = { [weak self] in self?.onRemotePlay?() }
        remoteCommands.onPause = { [weak self] in self?.onRemotePause?() }
        remoteCommands.onNext = { [weak self] in self?.onRemoteNext?() }
        remoteCommands.onPrevious = { [weak self] in self?.onRemotePrevious?() }
        remoteCommands.onSeek = { [weak self] position in self?.onRemoteSeek?(position) }

        audioSession.onPause = { [weak self] in self?.onRemotePause?() }
        audioSession.onPlay = { [weak self] in self?.onRemotePlay?() }
        audioSession.onReconfigureNeeded = { [weak self] in
            guard let self else {
                return
            }

            if let lastLoadedURL {
                load(url: lastLoadedURL)
            } else {
                audioSession.configureIfNeeded()
            }
        }
    }

    func load(url: URL) {
        audioSession.configureIfNeeded()

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
        remoteCommands.setNextTrackEnabled(enabled)
    }

    // MARK: - Private

    private static let timescale: CMTimeScale = 600
    private static let positionInterval = CMTime(seconds: 1, preferredTimescale: timescale)

    private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
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
}
