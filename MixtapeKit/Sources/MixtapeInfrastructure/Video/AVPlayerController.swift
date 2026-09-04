//  AVPlayerController.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import AVFoundation
import AVKit
import Foundation
import MixtapeDomain
import SwiftUI

/// The AVPlayer conformer: direct play of native containers and the HLS transcode playlist.
/// Presents through AVKit's `VideoPlayer` (decision 18) so transport controls, Picture in
/// Picture and AirPlay come from the platform.
public final class AVPlayerController: VideoPlayerControlling {
    public var onPositionChange: ((Duration) -> Void)?
    public var onTransportEvent: ((VideoTransportEvent) -> Void)?
    public var onEnded: (() -> Void)?
    public var onFailure: ((MixtapeError) -> Void)?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: (any NSObjectProtocol)?
    private var jumpObserver: (any NSObjectProtocol)?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    /// The `startAt` seek in `load` jumps the time too; that jump is not a user seek.
    private var isSeekingToStart = false

    public init() {}

    /// `headers` is ignored: the URL carries `ApiKey` (decision 42) and the private header key is never used.
    public func load(url: URL, startAt: Duration, headers _: [String: String]) {
        teardown()
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        if startAt > .zero {
            isSeekingToStart = true
            player.seek(to: Self.time(startAt), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                Task { @MainActor in self?.isSeekingToStart = false }
            }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { // the observer runs on the main queue
                self?.onPositionChange?(Self.duration(time))
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { // delivered on the main queue
                self?.onEnded?()
            }
        }
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            let message = item.error?.localizedDescription ?? "Playback failed"
            Task { @MainActor in
                self?.onFailure?(.transport(message))
            }
        }
        // AVKit's transport drives the player directly (decision 18), so the player's own state is
        // the only account of a pause or resume the service can get (slice 014).
        rateObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            let ended = player.currentItem.map { $0.duration.isNumeric && $0.currentTime() >= $0.duration } ?? false
            Task { @MainActor in
                switch status {
                case .paused where ended == false: self?.onTransportEvent?(.paused)
                case .playing: self?.onTransportEvent?(.resumed)
                case .paused, .waitingToPlayAtSpecifiedRate: break // the end-of-item pause precedes onEnded; waiting is buffering, not a pause
                @unknown default: break
                }
            }
        }
        // The only seek signal AVFoundation gives: fires for the system scrubber and for seek(to:) alike.
        jumpObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.timeJumpedNotification, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { // delivered on the main queue
                guard let self, self.isSeekingToStart == false else { return }
                self.onTransportEvent?(.seeked(Self.duration(self.player.currentTime())))
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
        player.seek(to: Self.time(position), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func teardown() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        if let jumpObserver {
            NotificationCenter.default.removeObserver(jumpObserver)
        }
        jumpObserver = nil
        statusObservation = nil
        rateObservation = nil
        isSeekingToStart = false
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    public func makeView() -> AnyView {
        AnyView(VideoPlayer(player: player))
    }

    private static func time(_ duration: Duration) -> CMTime {
        let parts = duration.components
        return CMTime(seconds: Double(parts.seconds) + Double(parts.attoseconds) / 1e18, preferredTimescale: 600)
    }

    private static func duration(_ time: CMTime) -> Duration {
        guard time.isNumeric else { return .zero }
        return .seconds(time.seconds)
    }
}
