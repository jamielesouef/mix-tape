//  MovieLibraryShelf.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(tvOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    public struct MovieLibraryShelf: View {
        @Environment(\.libraryService) private var libraryService
        let library: Library

        public init(library: Library) {
            self.library = library
        }

        public var body: some View {
            Group {
                switch libraryService.pages[library.id] {
                case .none, .idle, .loading:
                    ProgressView()
                case let .failed(error):
                    RetryView(error: error) { await libraryService.loadLibrary(id: library.id) }
                case let .loaded(page) where page.items.isEmpty:
                    ContentUnavailableView("No movies", systemImage: "film")
                case let .loaded(page):
                    PosterShelf(title: library.name, items: page.items) { await libraryService.loadMore(libraryID: library.id) }
                }
            }
            .task { await libraryService.loadLibrary(id: library.id) }
        }
    }

    #if DEBUG
        #Preview("loaded") {
            NavigationStack {
                MovieLibraryShelf(library: MockMedia.libraries[0])
            }
            .environment(\.libraryService, MockLibraryService.loaded())
        }

        #Preview("empty") {
            NavigationStack {
                MovieLibraryShelf(library: MockMedia.libraries[0])
            }
            .environment(\.libraryService, MockLibraryService.empty())
        }

        #Preview("failure") {
            NavigationStack {
                MovieLibraryShelf(library: MockMedia.libraries[0])
            }
            .environment(\.libraryService, MockLibraryService.failed())
        }
    #endif
#endif
