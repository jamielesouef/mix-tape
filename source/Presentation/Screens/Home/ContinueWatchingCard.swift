//  ContinueWatchingCard.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

struct ContinueWatchingCard: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(source: .item(item, item.backdropImageTag == nil ? .primary : .backdrop), maxHeight: 360, placeholder: "film")
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 10))
            ProgressView(value: item.progressFraction ?? 0)
                .tint(.accentColor)
            Text(item.displayTitle)
                .font(.footnote)
                .lineLimit(1)
                .foregroundStyle(.primary)
            if let seriesName = item.seriesName {
                Text(seriesName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 280)
    }
}

#if DEBUG
    #Preview("loaded") {
        ContinueWatchingCard(item: MockMedia.movies[1])
            .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        ContinueWatchingCard(item: MockMedia.movies[0])
            .environment(\.imageService, MockImageService.make())
    }

    #Preview("failure") {
        ContinueWatchingCard(item: MockMedia.episodes[1])
            .environment(\.imageService, MockImageService.make(sessionService: MockSessionService.signedOut()))
    }
#endif
