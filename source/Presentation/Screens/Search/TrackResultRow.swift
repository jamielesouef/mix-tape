//  TrackResultRow.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import SwiftUI

/// A track search result — title, its album, and duration. `TrackRow` (Album Detail's track
/// list) omits the album, since there every row already belongs to the same one.
struct TrackResultRow: View {
    // MARK: - Properties

    let track: MediaItem
    let albumTitle: String?

    // MARK: - Body

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(track.displayTitle)
                    .lineLimit(1)
                if let albumTitle {
                    Text(albumTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let runtime = track.runtime {
                Text(runtime, format: .time(pattern: .minuteSecond))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        List {
            TrackResultRow(track: MockMedia.tracks[0], albumTitle: MockMedia.albums[0].name)
        }
    }

    #Preview("empty") {
        List {
            TrackResultRow(track: MockMedia.tracks[1], albumTitle: nil)
        }
    }

    #Preview("failure") {
        List {
            TrackResultRow(track: MockMedia.tracks[1], albumTitle: MockMedia.albums[1].name)
        }
    }
#endif
