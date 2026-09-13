//  NowPlayingScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

public struct NowPlayingScreen: View {
    @Environment(\.musicPlayerService) private var music
    @State private var scrubbing: Double?

    public init() {}

    public var body: some View {
        VStack(spacing: 28) {
            if let track = music.current {
                RemoteImage(source: .item(track, .primary), maxHeight: 900, placeholder: "music.note")
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
                scrubber(track: track)
                controls
            } else {
                ContentUnavailableView("Nothing playing", systemImage: "music.note")
            }
        }
        .padding(32)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(NowPlayingIdentifiers.screen)
    }

    @ViewBuilder
    private func scrubber(track: MediaItem) -> some View {
        let total = track.runtime.map { Double($0.components.seconds) } ?? 1
        let value = Double(music.position.components.seconds)
        let position = Binding(get: { scrubbing ?? min(value, total) }, set: { scrubbing = $0 })
        Slider(value: position, in: 0 ... max(total, 1)) { editing in
            if editing == false, let target = scrubbing {
                music.seek(to: .seconds(target))
                scrubbing = nil
            }
        }
        .accessibilityIdentifier(NowPlayingIdentifiers.scrubber)
    }

    private var controls: some View {
        HStack(spacing: 44) {
            Button { Task { await music.previous() } } label: {
                Image(systemName: "backward.fill").font(.title)
            }
            .accessibilityLabel("Previous track")
            .accessibilityIdentifier(NowPlayingIdentifiers.previousButton)
            Button { music.togglePlayPause() } label: {
                Image(systemName: music.status == .playing ? "pause.fill" : "play.fill").font(.largeTitle)
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
