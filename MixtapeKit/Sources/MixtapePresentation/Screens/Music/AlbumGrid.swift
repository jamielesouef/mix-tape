//  AlbumGrid.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// The plain album grid, shared by both platforms this slice. On iOS the wallet replaces it in
/// slice 010 and this becomes tvOS-only.
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
