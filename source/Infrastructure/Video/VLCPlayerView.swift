//  VLCPlayerView.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import SwiftUI
import UIKit

struct VLCPlayerView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency: Bool
    @State var model: VLCTransportModel
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

    private var transportBackground: AnyShapeStyle {
        // glass-fallback: this line is the fallback — opaque black when Reduce Transparency is on.
        reduceTransparency ? AnyShapeStyle(.black) : AnyShapeStyle(.ultraThinMaterial)
    }
}
