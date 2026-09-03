//  MediaItemDestination.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// The detail screen for a pushed `MediaItem`, chosen by kind. Every `NavigationStack` that pushes
/// items declares this once as its `navigationDestination(for: MediaItem.self)`.
struct MediaItemDestination: View {
    let item: MediaItem

    var body: some View {
        switch item.kind {
        case .movie, .episode:
            MovieDetailScreen(item: item)
        case .series:
            SeriesDetailScreen(series: item)
        case .musicAlbum:
            AlbumDetailScreen(album: item)
        case .season, .audio:
            ContentUnavailableView(item.displayTitle, systemImage: "questionmark.square.dashed")
        }
    }
}

#Preview("loaded") {
    NavigationStack {
        MediaItemDestination(item: MockMedia.movies[1])
    }
    .environment(\.libraryService, MockLibraryService.loaded())
}

#Preview("empty") {
    NavigationStack {
        MediaItemDestination(item: MockMedia.tracks[0])
    }
}

#Preview("failure") {
    NavigationStack {
        MediaItemDestination(item: MockMedia.series)
    }
    .environment(\.seriesService, MockSeriesService.failed())
}
