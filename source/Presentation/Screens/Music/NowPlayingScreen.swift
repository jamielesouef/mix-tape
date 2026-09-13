//  NowPlayingScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

struct NowPlayingScreen: View {
    @Environment(\.musicPlayerService) private var music: MusicPlayerService

    init() {}

    var body: some View {
        VStack(spacing: 28) {
            if let track = music.current {
                RemoteImage(
                    source: .item(track, .primary),
                    maxHeight: 900,
                    placeholder: "music.note"
                )
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 360)
                .clipShape(.rect(cornerRadius: 16))

                VStack(spacing: 6) {
                    Text(track.displayTitle)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(NowPlayingIdentifiers.titleLabel)
                    Text(track.albumArtist ?? music.album?.albumArtist ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                NowPlayingScrubber(track: track)
                NowPlayingControls()
            } else {
                ContentUnavailableView("Nothing playing", systemImage: "music.note")
            }
        }
        .padding(32)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(NowPlayingIdentifiers.screen)
    }
}

#if DEBUG
    #Preview("loaded") {
        NowPlayingScreen().environment(\.musicPlayerService, MockMusicPlayerService.playing())
    }

    #Preview("empty") {
        NowPlayingScreen().environment(\.musicPlayerService, MockMusicPlayerService.idle())
    }

    #Preview("failure") {
        NowPlayingScreen().environment(\.musicPlayerService, MockMusicPlayerService.idle())
    }
#endif
