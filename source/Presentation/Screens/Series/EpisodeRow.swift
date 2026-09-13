//  EpisodeRow.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import SwiftUI

struct EpisodeRow: View {
    let episode: MediaItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImage(source: .item(episode, .primary), maxHeight: 180, placeholder: "tv")
                .frame(width: 128, height: 72)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 6) {
                Text(episode.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                if let runtime = episode.runtime {
                    Text(runtime.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let fraction = episode.progressFraction {
                    ProgressView(value: fraction)
                        .tint(.accentColor)
                }
            }
        }
    }
}

#if DEBUG
    #Preview("loaded") {
        List {
            EpisodeRow(episode: MockMedia.episodes[1])
        }
        .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        List {
            EpisodeRow(episode: MockMedia.episodes[0])
        }
        .environment(\.imageService, MockImageService.make())
    }

    #Preview("failure") {
        List {
            EpisodeRow(episode: MockMedia.episodes[0])
        }
        .environment(\.imageService, MockImageService.make(sessionService: MockSessionService.signedOut()))
    }
#endif
