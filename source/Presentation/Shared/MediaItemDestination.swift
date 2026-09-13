//  MediaItemDestination.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

struct MediaItemDestination: View {
    let item: MediaItem

    var body: some View {
        switch item.kind {
        case .musicAlbum:
            AlbumDetailScreen(album: item)
        case .audio:
            ContentUnavailableView(item.displayTitle, systemImage: "questionmark.square.dashed")
        }
    }
}

#if DEBUG
    #Preview("loaded") {
        NavigationStack {
            MediaItemDestination(item: MockMedia.albums[0])
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
            MediaItemDestination(item: MockMedia.albums[1])
        }
        .environment(\.libraryService, MockLibraryService.failed())
    }
#endif
