//  VLCPlayerController.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(iOS) || os(tvOS)
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

    /// The libVLC conformer for `.directVLC`: a file AVPlayer refuses, played in-app with no
    /// server transcode. This is the **only** file in the codebase that imports libVLC (decision
    /// 44); the module is `MobileVLCKit` on iOS and `TVVLCKit` on tvOS, never a bare `VLCKit`.
    /// VLC has no native SwiftUI transport, so `makeView()` returns the video surface under a
    /// hand-built overlay (decision 18). The stream URL already carries `ApiKey` (decision 42),
    /// so `VLCMedia` is created with no options.
    public final class VLCPlayerController: NSObject, VideoPlayerControlling, VLCMediaPlayerDelegate {
        public var onPositionChange: ((Duration) -> Void)?
        public var onEnded: (() -> Void)?
        public var onFailure: ((MixtapeError) -> Void)?

        private let player: VLCMediaPlayer
        private let videoView = UIView()
        private let model = VLCTransportModel()
        private var startPosition: Duration = .zero
        private var didSeekToStart = false

        override public init() {
            // A nonisolated logger, installed on the library this player uses, or VLC's logging
            // thread traps under MainActor default isolation (decision 44).
            let library = VLCLibrary(options: [])
            library.loggers = [VLCBridgeLogger()]
            player = VLCMediaPlayer(library: library)
            super.init()
            player.delegate = self
            player.drawable = videoView
        }

        public func load(url: URL, startAt: Duration, headers _: [String: String]) {
            startPosition = startAt
            didSeekToStart = false
            player.media = VLCMedia(url: url) // ApiKey rides in the URL; no VLCMedia options
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
        }

        public func teardown() {
            player.stop()
            player.media = nil
        }

        public func makeView() -> AnyView {
            AnyView(VLCPlayerView(model: model, videoView: videoView, controller: self))
        }

        /// Toggle used by the overlay so it never has to read `PlayerStatus`.
        func toggle() {
            if model.isPlaying {
                pause()
            } else {
                play()
            }
        }

        /// Overlay scrub: `fraction` is 0…1 of the media.
        func scrub(to fraction: Double) {
            player.position = Float(min(max(fraction, 0), 1))
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
            case .paused, .stopped:
                model.isPlaying = false
            default:
                break
            }
        }
    }

    /// The overlay's observable state. VLC drives it; the SwiftUI overlay reads it.
    @Observable
    final class VLCTransportModel {
        var isPlaying = false
        var positionFraction: Double = 0
    }

    /// Hosts VLC's video surface and the custom transport (decision 18). Lives here rather than in
    /// Presentation so the "one file imports libVLC" rule holds — it needs `VLCVideoView`.
    private struct VLCPlayerView: View {
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        @State var model: VLCTransportModel
        let videoView: UIView
        let controller: VLCPlayerController

        var body: some View {
            ZStack {
                VLCVideoSurface(videoView: videoView)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Button {
                            controller.toggle()
                        } label: {
                            Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityIdentifier("vlcPlayer.playPauseButton")
                        #if os(iOS)
                            // Siri Remote scrubbing on tvOS is slice 011; here tvOS shows a read-only bar.
                            Slider(
                                value: Binding(get: { model.positionFraction }, set: { controller.scrub(to: $0) }),
                                in: 0 ... 1,
                            )
                            .accessibilityIdentifier("vlcPlayer.scrubber")
                        #else
                            ProgressView(value: model.positionFraction)
                                .accessibilityIdentifier("vlcPlayer.scrubber")
                        #endif
                    }
                    .padding()
                    .background(transportBackground, in: .rect(cornerRadius: 16))
                    .padding()
                }
                .foregroundStyle(.white)
            }
        }

        /// Liquid Glass with the required Reduce Transparency fallback (engineering doc §9).
        private var transportBackground: AnyShapeStyle {
            reduceTransparency ? AnyShapeStyle(.black.opacity(0.8)) : AnyShapeStyle(.ultraThinMaterial)
        }
    }

    /// libVLC renders into any `UIView` set as the player's `drawable` (the public `VLCVideoView`
    /// is only forward-declared), so this wraps a plain `UIView` for SwiftUI.
    private struct VLCVideoSurface: UIViewRepresentable {
        let videoView: UIView

        func makeUIView(context _: Context) -> UIView {
            videoView
        }

        func updateUIView(_: UIView, context _: Context) {}
    }

    /// libVLC calls its logger from its own thread, so this conformer must be `nonisolated` or it
    /// `SIGTRAP`s under decision 15's MainActor default (decision 44). Warnings and errors go to
    /// the `playback` log; info and debug are dropped.
    private final class VLCBridgeLogger: NSObject, VLCLogging, @unchecked Sendable {
        /// Computed (not stored) so it can be nonisolated: VLC reads it from its own thread.
        nonisolated var level: VLCLogLevel {
            get { .warning }
            set {}
        }

        nonisolated func handleMessage(_ message: String, logLevel: VLCLogLevel, context _: VLCLogContext?) {
            guard logLevel.rawValue <= VLCLogLevel.warning.rawValue else { return }
            AppLogger.playback.error("VLC: \(message)")
        }
    }
#endif
