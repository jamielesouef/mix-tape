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
    public var onEnded: (() -> Void)?
    public var onFailure: ((MixtapeError) -> Void)?

    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: (any NSObjectProtocol)?
    private var statusObservation: NSKeyValueObservation?

    public init() {}

    /// `headers` is ignored: the URL carries `ApiKey` (decision 42) and the private header key is never used.
    public func load(url: URL, startAt: Duration, headers _: [String: String]) {
        teardown()
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        if startAt > .zero {
            player.seek(to: Self.time(startAt), toleranceBefore: .zero, toleranceAfter: .zero)
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
        statusObservation = nil
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
