//  VLCPlayerView+iOS.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(iOS)
    import SwiftUI
    import UIKit

    /// Hosts VLC's video surface under the touch transport (decision 18): play/pause and a scrub
    /// slider. Lives in Infrastructure because Presentation only ever sees the controller's `AnyView`.
    struct VLCPlayerView: View {
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
        @State var model: VLCTransportModel
        /// The fraction under the finger while dragging; one `scrub` fires on release (slice 019).
        @State private var scrubbing: Double?
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
                        .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
                        .accessibilityIdentifier(VLCPlayerIdentifiers.playPauseButton)
                        Slider(value: Binding(get: { scrubbing ?? model.positionFraction }, set: { scrubbing = $0 }), in: 0 ... 1) { editing in
                            if editing == false, let target = scrubbing {
                                controller.scrub(to: target)
                                scrubbing = nil
                            }
                        }
                        .accessibilityLabel("Playback position")
                        .accessibilityIdentifier(VLCPlayerIdentifiers.scrubber)
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
            // glass-fallback: the ternary is the fallback — opaque black when reduced (slice 019).
            reduceTransparency ? AnyShapeStyle(.black) : AnyShapeStyle(.ultraThinMaterial)
        }
    }
#endif
