//  MiniPlayer.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// The docked mini player above the iOS tab bar, shown whenever music is active. Tapping it opens
/// `NowPlayingScreen`. Liquid Glass with the Reduce Transparency fallback (§9).
struct MiniPlayer: View {
    @Environment(\.musicPlayerService) private var music
    @State private var showNowPlaying = false

    var body: some View {
        if music.isActive, let track = music.current {
            Button { showNowPlaying = true } label: {
                HStack(spacing: 12) {
                    RemoteImage(source: .item(track, .primary), maxHeight: 120, placeholder: "music.note")
                        .frame(width: 40, height: 40)
                        .clipShape(.rect(cornerRadius: 6))
                    Text(track.displayTitle)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Button { music.togglePlayPause() } label: {
                        Image(systemName: music.status == .playing ? "pause.fill" : "play.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(MiniPlayerIdentifiers.playPauseButton)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .glassChrome(cornerRadius: 12)
            .padding(.horizontal)
            .accessibilityIdentifier(MiniPlayerIdentifiers.bar)
            .sheet(isPresented: $showNowPlaying) {
                NowPlayingScreen()
            }
        }
    }
}

#Preview("loaded") {
    MiniPlayer().environment(\.musicPlayerService, MockMusicPlayerService.playing())
}

#Preview("empty") {
    MiniPlayer().environment(\.musicPlayerService, MockMusicPlayerService.idle())
}

#Preview("failure") {
    MiniPlayer().environment(\.musicPlayerService, MockMusicPlayerService.idle())
}
