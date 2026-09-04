//  AlbumGrid.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(tvOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    /// The plain album grid, tvOS only since slice 010 — iOS has the wallet (engineering doc §1.1, §9.1).
    /// Slice 011 gives it shelf chrome.
    public struct AlbumGrid: View {
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
                    ContentUnavailableView("No albums", systemImage: "music.note")
                case let .loaded(page):
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 20, alignment: .top)], spacing: 24) {
                            ForEach(page.items) { album in
                                NavigationLink(value: album) {
                                    PosterCard(item: album, aspectRatio: 1)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(AlbumGridIdentifiers.cell(album.id))
                                .task {
                                    if album.id == page.items.last?.id {
                                        await libraryService.loadMore(libraryID: library.id)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .accessibilityIdentifier(AlbumGridIdentifiers.grid)
                }
            }
            .navigationTitle(library.name)
            .task { await libraryService.loadLibrary(id: library.id) }
        }
    }

    #Preview("loaded") {
        NavigationStack {
            AlbumGrid(library: MockMedia.libraries[2])
        }
        .environment(\.libraryService, MockLibraryService.loaded())
    }

    #Preview("empty") {
        NavigationStack {
            AlbumGrid(library: MockMedia.libraries[2])
        }
        .environment(\.libraryService, MockLibraryService.empty())
    }

    #Preview("failure") {
        NavigationStack {
            AlbumGrid(library: MockMedia.libraries[2])
        }
        .environment(\.libraryService, MockLibraryService.failed())
    }
#endif
