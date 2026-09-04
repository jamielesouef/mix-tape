//  NowPlayingScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// Art, title, scrubber, previous / play / next. No shuffle, no repeat, no queue button (§1.1, §9).
public struct NowPlayingScreen: View {
    @Environment(\.musicPlayerService) private var music

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
        #if os(iOS)
            // tvOS shows a read-only bar: engineering doc §9's tvOS table asks for no divergence here (slice 011).
            Slider(value: Binding(get: { min(value, total) }, set: { music.seek(to: .seconds($0)) }), in: 0 ... max(total, 1))
                .accessibilityIdentifier(NowPlayingIdentifiers.scrubber)
        #else
            ProgressView(value: min(value, total), total: max(total, 1))
                .accessibilityIdentifier(NowPlayingIdentifiers.scrubber)
        #endif
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
