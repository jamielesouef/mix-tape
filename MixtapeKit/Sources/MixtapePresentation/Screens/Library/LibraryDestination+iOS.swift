//  LibraryDestination+iOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(iOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    struct LibraryDestination: View {
        let library: Library

        var body: some View {
            switch library.kind {
            case .movies:
                MovieLibraryGrid(library: library)
            case .tvShows:
                SeriesLibraryGrid(library: library)
            case .music:
                WalletScreen(library: library)
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
