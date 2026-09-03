//  LibraryDestination.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// The grid for a pushed `Library`, chosen by kind.
struct LibraryDestination: View {
    let library: Library

    var body: some View {
        switch library.kind {
        case .movies:
            MovieLibraryGrid(library: library)
        case .tvShows:
            SeriesLibraryGrid(library: library)
        case .music:
            AlbumGrid(library: library)
        case .unsupported:
            ContentUnavailableView(library.name, systemImage: "questionmark.folder")
        }
    }
}

#Preview("loaded") {
    NavigationStack {
        LibraryDestination(library: MockMedia.libraries[0])
    }
    .environment(\.libraryService, MockLibraryService.loaded())
}

#Preview("empty") {
    NavigationStack {
        LibraryDestination(library: MockMedia.libraries[3])
    }
}

#Preview("failure") {
    NavigationStack {
        LibraryDestination(library: MockMedia.libraries[2])
    }
    .environment(\.libraryService, MockLibraryService.failed())
}
