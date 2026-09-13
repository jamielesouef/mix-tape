//  TrackRow.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import SwiftUI

struct TrackRow: View {
    // MARK: - Properties

    let track: MediaItem

    // MARK: - Body

    var body: some View {
        HStack {
            Text(track.displayTitle)
                .lineLimit(1)
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
            TrackRow(track: MockMedia.tracks[0])
        }
    }

    #Preview("empty") {
        List {
            TrackRow(track: MockMedia.tracks[1])
        }
    }

    #Preview("failure") {
        List {
            TrackRow(track: MockMedia.tracks[1])
        }
    }
#endif
