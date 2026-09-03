//  VideoPlayerScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// Full-screen cover hosting the selected player's view plus a small overlay. AVKit supplies the
/// transport controls (decision 18); the overlay adds Close and surfaces preparing / failure.
public struct VideoPlayerScreen: View {
    @Environment(\.videoPlaybackService) private var videoPlaybackService
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let playerView = videoPlaybackService.playerView {
                playerView.ignoresSafeArea()
            }
            switch videoPlaybackService.status {
            case .preparing:
                ProgressView("Preparing…")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier(VideoPlayerIdentifiers.statusLabel)
            case let .failed(error):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text(error.message)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(VideoPlayerIdentifiers.statusLabel)
                }
                .foregroundStyle(.white)
                .padding(24)
                .glassChrome()
                .padding()
            case .idle, .playing, .paused:
                EmptyView()
            }
        }
        .overlay(alignment: .topLeading) {
            Button("Close", systemImage: "xmark") {
                Task {
                    await videoPlaybackService.stop()
                    dismiss()
                }
            }
            .labelStyle(.iconOnly)
            .padding(12)
            .glassChrome(cornerRadius: 24)
            .padding()
            .accessibilityIdentifier(VideoPlayerIdentifiers.closeButton)
        }
        .accessibilityIdentifier(VideoPlayerIdentifiers.screen)
    }
}

#Preview("loaded") {
    VideoPlayerScreen().environment(\.videoPlaybackService, MockVideoPlaybackService.playing())
}

#Preview("empty") {
    VideoPlayerScreen().environment(\.videoPlaybackService, MockVideoPlaybackService.preparing())
}

#Preview("failure") {
    VideoPlayerScreen().environment(\.videoPlaybackService, MockVideoPlaybackService.failed(.noPlayableSource))
}
