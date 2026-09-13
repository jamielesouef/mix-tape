//  TrackRow.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import SwiftUI

struct TrackRow: View {
    let track: MediaItem

    var body: some View {
        HStack {
            Text(track.displayTitle)
                .lineLimit(1)
            Spacer()
            if let runtime = track.runtime {
                Text(runtime.formatted(.time(pattern: .minuteSecond)))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

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
