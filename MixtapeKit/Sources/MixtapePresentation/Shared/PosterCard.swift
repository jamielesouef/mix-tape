//  PosterCard.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// Art over a title, with a progress bar when the item has a resume point. `aspectRatio` is
/// width over height: 2:3 for posters, 1 for album art.
struct PosterCard: View {
    let item: MediaItem
    var aspectRatio: CGFloat = 2 / 3

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RemoteImage(source: .item(item, .primary), maxHeight: 450, placeholder: item.kind == .musicAlbum ? "music.note" : "film")
                .aspectRatio(aspectRatio, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 8))
            if let fraction = item.progressFraction {
                ProgressView(value: fraction)
                    .tint(.accentColor)
            }
            Text(item.displayTitle)
                .font(.footnote)
                .lineLimit(2)
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var subtitle: String? {
        switch item.kind {
        case .musicAlbum: item.albumArtist
        case .episode: item.seriesName
        case .movie, .series, .season, .audio: item.productionYear.map(String.init)
        }
    }
}

#if DEBUG
    #Preview("loaded") {
        PosterCard(item: MockMedia.movies[1])
            .frame(width: 160)
            .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        PosterCard(item: MockMedia.albums[0], aspectRatio: 1)
            .frame(width: 160)
            .environment(\.imageService, MockImageService.make())
    }

    #Preview("failure") {
        PosterCard(item: MockMedia.movies[0])
            .frame(width: 160)
            .environment(\.imageService, MockImageService.make(sessionService: MockSessionService.signedOut()))
    }
#endif
