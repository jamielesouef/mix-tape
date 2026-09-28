//  NowPlayingScrubber.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import SwiftUI

struct NowPlayingScrubber: View {
    // MARK: - Properties

    @Environment(\.musicPlayerService) private var music: MusicPlayerService
    @State private var displaySeconds: Double = 0
    @State private var isDragging = false
    let track: MediaItem

    // MARK: - Body

    var body: some View {
        Slider(value: $displaySeconds, in: 0 ... max(trackSeconds, 1)) { dragging in
            isDragging = dragging

            if dragging == false {
                music.seek(to: .seconds(displaySeconds))
            }
        }
        .accessibilityIdentifier(NowPlayingIdentifiers.scrubber)
        .task(id: track.id) {
            displaySeconds = playedSeconds
        }
        .onChange(of: music.position) { _, _ in
            guard isDragging == false else {
                return
            }

            displaySeconds = playedSeconds
        }
    }

    // MARK: - Private

    private var trackSeconds: Double {
        track.runtime.map { Double($0.components.seconds) } ?? 1
    }

    /// While a drag is in progress the thumb follows the finger, not the player, so that
    /// position updates arriving mid-drag do not yank it back.
    private var playedSeconds: Double {
        min(Double(music.position.components.seconds), trackSeconds)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        NowPlayingScrubber(track: MockMedia.tracks[0])
            .environment(\.musicPlayerService, MockMusicPlayerService.playing())
            .padding()
    }

    #Preview("empty") {
        NowPlayingScrubber(track: MockMedia.tracks[0])
            .environment(\.musicPlayerService, MockMusicPlayerService.idle())
            .padding()
    }

    #Preview("failure") {
        NowPlayingScrubber(track: MockMedia.tracks[1])
            .environment(\.musicPlayerService, MockMusicPlayerService.idle())
            .padding()
    }
#endif
