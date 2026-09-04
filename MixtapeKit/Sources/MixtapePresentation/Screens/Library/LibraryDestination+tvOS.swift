//  LibraryDestination+tvOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(tvOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    /// The shelf for a `Library`, chosen by kind: the tvOS tabs host it and Home's pushes reach it.
    struct LibraryDestination: View {
        let library: Library

        var body: some View {
            switch library.kind {
            case .movies:
                MovieLibraryShelf(library: library)
            case .tvShows:
                SeriesLibraryShelf(library: library)
            case .music:
                AlbumGrid(library: library)
            case .unsupported:
                ContentUnavailableView(library.name, systemImage: "questionmark.folder")
            }
        }
    }

    #if DEBUG
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
    #endif
#endif
