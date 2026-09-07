//  VLCPlayerView+tvOS.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(tvOS)
    import SwiftUI
    import UIKit

    /// Hosts VLC's video surface under a Siri Remote transport (engineering doc §9, tvOS table):
    /// Play/Pause on the remote or select on the focused button toggles, a swipe or arrow left/right
    /// steps the position by ten seconds. Menu leaves through the hosting cover.
    struct VLCPlayerView: View {
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        // The cover's Close button is outside this view; unless focus starts here the remote's
        // Play/Pause and swipe commands never reach the modifiers below.
        @FocusState private var transportFocused: Bool
        @State var model: VLCTransportModel
        let videoView: UIView
        let controller: VLCPlayerController

        var body: some View {
            ZStack {
                VLCVideoSurface(videoView: videoView)
                    .ignoresSafeArea()
                VStack {
                    Spacer()
                    HStack(spacing: 32) {
                        Button {
                            controller.toggle()
                        } label: {
                            Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                        .focused($transportFocused)
                        .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
                        .accessibilityIdentifier(VLCPlayerIdentifiers.playPauseButton)
                        ProgressView(value: model.positionFraction)
                            .accessibilityLabel("Playback position")
                            .accessibilityIdentifier(VLCPlayerIdentifiers.scrubber)
                        Text("Swipe to scrub")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .background(transportBackground, in: .rect(cornerRadius: 24))
                    .padding(60)
                }
                .foregroundStyle(.white)
            }
            .onAppear { transportFocused = true }
            .onPlayPauseCommand { controller.toggle() }
            .onMoveCommand { direction in
                switch direction {
                case .left: controller.step(by: -10)
                case .right: controller.step(by: 10)
                case .up, .down: break
                @unknown default: break
                }
            }
        }

        /// Liquid Glass with the required Reduce Transparency fallback (engineering doc §9).
        private var transportBackground: AnyShapeStyle {
            // glass-fallback: the ternary is the fallback — opaque black when reduced (slice 019).
            reduceTransparency ? AnyShapeStyle(.black) : AnyShapeStyle(.ultraThinMaterial)
        }
    }
#endif
