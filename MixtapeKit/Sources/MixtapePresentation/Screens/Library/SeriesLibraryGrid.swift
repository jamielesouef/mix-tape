//  SeriesLibraryGrid.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(iOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    public struct SeriesLibraryGrid: View {
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
                    ContentUnavailableView("No shows", systemImage: "tv")
                case let .loaded(page):
                    PosterGrid(items: page.items) { await libraryService.loadMore(libraryID: library.id) }
                }
            }
            .navigationTitle(library.name)
            .task { await libraryService.loadLibrary(id: library.id) }
        }
    }

    #if DEBUG
        #Preview("loaded") {
            NavigationStack {
                SeriesLibraryGrid(library: MockMedia.libraries[1])
            }
            .environment(\.libraryService, MockLibraryService.loaded())
        }

        #Preview("empty") {
            NavigationStack {
                SeriesLibraryGrid(library: MockMedia.libraries[1])
            }
            .environment(\.libraryService, MockLibraryService.empty())
        }

        #Preview("failure") {
            NavigationStack {
                SeriesLibraryGrid(library: MockMedia.libraries[1])
            }
            .environment(\.libraryService, MockLibraryService.failed())
        }
    #endif
#endif
