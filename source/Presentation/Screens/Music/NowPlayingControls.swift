//  NowPlayingControls.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import SwiftUI

struct NowPlayingControls: View {
    // MARK: - Properties

    @Environment(\.musicPlayerService) private var music: MusicPlayerService

    // MARK: - Body

    var body: some View {
        HStack(spacing: 44) {
            Button { Task { await music.previous() } } label: {
                Image(systemName: "backward.fill").font(.title)
            }
            .accessibilityLabel("Previous track")
            .accessibilityIdentifier(NowPlayingIdentifiers.previousButton)

            Button { music.togglePlayPause() } label: {
                Image(systemName: music.status == .playing ? "pause.fill" : "play.fill")
                    .font(.largeTitle)
            }
            .accessibilityLabel(music.status == .playing ? "Pause" : "Play")
            .accessibilityIdentifier(NowPlayingIdentifiers.playPauseButton)

            Button { Task { await music.next() } } label: {
                Image(systemName: "forward.fill").font(.title)
            }
            .disabled(music.hasNextTrack == false)
            .accessibilityLabel("Next track")
            .accessibilityIdentifier(NowPlayingIdentifiers.nextButton)
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        NowPlayingControls().environment(\.musicPlayerService, MockMusicPlayerService.playing())
    }

    #Preview("empty") {
        NowPlayingControls().environment(\.musicPlayerService, MockMusicPlayerService.idle())
    }

    #Preview("failure") {
        NowPlayingControls().environment(\.musicPlayerService, MockMusicPlayerService.idle())
    }
#endif
