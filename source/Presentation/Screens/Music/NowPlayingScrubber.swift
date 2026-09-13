//  NowPlayingScrubber.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import SwiftUI

struct NowPlayingScrubber: View {
    @Environment(\.musicPlayerService) private var music: MusicPlayerService
    @State private var draggedSeconds: Double?
    let track: MediaItem

    var body: some View {
        Slider(value: scrubPosition, in: 0 ... max(trackSeconds, 1)) { isDragging in
            guard isDragging == false, let draggedSeconds else {
                return
            }

            music.seek(to: .seconds(draggedSeconds))

            self.draggedSeconds = nil
        }
        .accessibilityIdentifier(NowPlayingIdentifiers.scrubber)
    }

    private var trackSeconds: Double {
        track.runtime.map { Double($0.components.seconds) } ?? 1
    }

    /// While a drag is in progress the thumb follows the finger, not the player, so that
    /// position updates arriving mid-drag do not yank it back.
    private var scrubPosition: Binding<Double> {
        Binding(
            get: {
                let played = Double(music.position.components.seconds)
                return draggedSeconds ?? min(played, trackSeconds)
            },
            set: { draggedSeconds = $0 }
        )
    }
}

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
