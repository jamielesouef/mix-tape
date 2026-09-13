//  VLCPlayerView+tvOS.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(tvOS)
    import SwiftUI
    import UIKit

    struct VLCPlayerView: View {
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
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

        private var transportBackground: AnyShapeStyle {
            reduceTransparency ? AnyShapeStyle(.black) : AnyShapeStyle(.ultraThinMaterial)
        }
    }
#endif
