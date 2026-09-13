//  VLCPlayerController.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(iOS) || os(tvOS)
    import AVFoundation
    import Foundation
    import MixtapeDomain
    import Observation
    import SwiftUI
    import UIKit

    #if os(iOS)
        import MobileVLCKit
    #elseif os(tvOS)
        import TVVLCKit
    #endif

    public final class VLCPlayerController: NSObject, VideoPlayerControlling, VLCMediaPlayerDelegate {
        public var onPositionChange: ((Duration) -> Void)?
        public var onTransportEvent: ((VideoTransportEvent) -> Void)?
        public var onEnded: (() -> Void)?
        public var onFailure: ((MixtapeError) -> Void)?

        private let player: VLCMediaPlayer
        private let videoView = UIView()
        private let model = VLCTransportModel()
        private var startPosition: Duration = .zero
        private var didSeekToStart = false
        private var didConfigureSession = false

        override public init() {
            let library = VLCLibrary(options: [])
            library.loggers = [VLCBridgeLogger()]
            player = VLCMediaPlayer(library: library)
            super.init()
            player.delegate = self
            player.drawable = videoView
        }

        public func load(url: URL, startAt: Duration, headers _: [String: String]) {
            configureSessionIfNeeded()
            startPosition = startAt
            didSeekToStart = false
            player.media = VLCMedia(url: url)
        }

        private func configureSessionIfNeeded() {
            guard didConfigureSession == false else { return }
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                didConfigureSession = true
                AppLogger.playback.info("VLC video audio session configured: category .playback, active")
            } catch {
                AppLogger.playback.error("VLC video audio session configuration failed: \(error.localizedDescription)")
            }
        }

        public func play() {
            player.play()
            model.isPlaying = true
        }

        public func pause() {
            player.pause()
            model.isPlaying = false
        }

        public func seek(to position: Duration) {
            player.time = VLCTime(int: Int32(position.components.seconds * 1000))
            onTransportEvent?(.seeked(position))
        }

        public func teardown() {
            player.stop()
            player.media = nil
        }

        public func makeView() -> AnyView {
            AnyView(VLCPlayerView(model: model, videoView: videoView, controller: self))
        }

        func toggle() {
            if model.isPlaying {
                pause()
            } else {
                play()
            }
        }

        func scrub(to fraction: Double) {
            let clamped = min(max(fraction, 0), 1)
            player.position = Float(clamped)
            let length = Double(player.media?.length.intValue ?? 0) / 1000
            onTransportEvent?(.seeked(.seconds(clamped * length)))
        }

        func step(by seconds: Double) {
            let current = Double(player.time.intValue) / 1000
            seek(to: .seconds(max(0, current + seconds)))
        }

        // MARK: - VLCMediaPlayerDelegate (callbacks arrive on the main thread — S002)

        public func mediaPlayerTimeChanged(_: Notification) {
            let seconds = Double(player.time.intValue) / 1000
            model.isPlaying = player.isPlaying
            model.positionFraction = Double(player.position)
            onPositionChange?(.seconds(seconds))
            if didSeekToStart == false, startPosition > .zero, player.isPlaying {
                didSeekToStart = true
                seek(to: startPosition)
            }
        }

        public func mediaPlayerStateChanged(_: Notification) {
            switch player.state {
            case .ended:
                onEnded?()
            case .error:
                onFailure?(.transport("VLC could not play this item"))
            case .playing:
                model.isPlaying = true
                onTransportEvent?(.resumed)
            case .paused:
                model.isPlaying = false
                onTransportEvent?(.paused)
            case .stopped:
                model.isPlaying = false
            default:
                break
            }
        }
    }

    private final class VLCBridgeLogger: NSObject, VLCLogging, @unchecked Sendable {
        nonisolated var level: VLCLogLevel {
            get { .warning }
            set {}
        }

        nonisolated func handleMessage(_ message: String, logLevel: VLCLogLevel, context _: VLCLogContext?) {
            guard logLevel.rawValue <= VLCLogLevel.warning.rawValue else { return }
            AppLogger.playback.error("VLC \(logLevel.rawValue): \(redactingURLs(message))")
        }
    }
#endif
