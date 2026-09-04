//  AlbumGrid.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(tvOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    /// The tvOS album shelf — iOS has the wallet (engineering doc §1.1, §9.1). The library title over a
    /// focus-driven grid of album cards, paged as the last card appears.
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
                        VStack(alignment: .leading, spacing: 32) {
                            Text(library.name)
                                .font(.title.bold())
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 40, alignment: .top), count: 6), spacing: 48) {
                                ForEach(page.items) { album in
                                    NavigationLink(value: album) {
                                        PosterCard(item: album, aspectRatio: 1)
                                    }
                                    .buttonStyle(.card)
                                    .accessibilityIdentifier(AlbumGridIdentifiers.cell(album.id))
                                    .task {
                                        if album.id == page.items.last?.id {
                                            await libraryService.loadMore(libraryID: library.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(60)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AlbumGridIdentifiers.grid)
                }
            }
            .task { await libraryService.loadLibrary(id: library.id) }
        }
    }

    #if DEBUG
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
#endif
