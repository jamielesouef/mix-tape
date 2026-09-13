//  MiniPlayer.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

struct MiniPlayer: View {
    @Environment(\.musicPlayerService) private var music: MusicPlayerService
    @Binding var showNowPlaying: Bool

    var body: some View {
        if let track = Self.dockedTrack(in: music) {
            HStack(spacing: 12) {
                Button { showNowPlaying = true } label: {
                    HStack(spacing: 12) {
                        RemoteImage(source: .item(track, .primary), maxHeight: 120, placeholder: "music.note")
                            .frame(width: 40, height: 40)
                            .clipShape(.rect(cornerRadius: 6))
                        Text(track.displayTitle)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Now playing, \(track.displayTitle)")
                .accessibilityIdentifier(MiniPlayerIdentifiers.bar)
                Button { music.togglePlayPause() } label: {
                    Image(systemName: music.status == .playing ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(music.status == .playing ? "Pause" : "Play")
                .accessibilityIdentifier(MiniPlayerIdentifiers.playPauseButton)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(.primary)
            .glassChrome(cornerRadius: 12)
            .padding(.horizontal)
        }
    }

    static func dockedTrack(in music: MusicPlayerService) -> MediaItem? {
        music.isActive ? music.current : nil
    }
}

#if DEBUG
    #Preview("loaded") {
        @Previewable @State var showNowPlaying = false
        MiniPlayer(showNowPlaying: $showNowPlaying).environment(\.musicPlayerService, MockMusicPlayerService.playing())
    }

    #Preview("empty") {
        @Previewable @State var showNowPlaying = false
        MiniPlayer(showNowPlaying: $showNowPlaying).environment(\.musicPlayerService, MockMusicPlayerService.idle())
    }

    #Preview("failure") {
        @Previewable @State var showNowPlaying = false
        MiniPlayer(showNowPlaying: $showNowPlaying).environment(\.musicPlayerService, MockMusicPlayerService.idle())
    }
#endif
