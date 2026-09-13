//  LibraryListScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

struct LibraryListScreen: View {
    @Environment(\.libraryService) private var libraryService: LibraryService

    init() {}

    var body: some View {
        NavigationStack {
            Group {
                switch libraryService.libraries {
                case .idle, .loading:
                    ProgressView()
                case let .failed(error):
                    RetryView(error: error) { await libraryService.loadHome() }
                case let .loaded(libraries) where libraries.isEmpty:
                    ContentUnavailableView("No libraries", systemImage: "books.vertical", description: Text("This user has no music libraries."))
                case let .loaded(libraries):
                    List(libraries) { library in
                        NavigationLink(value: library) {
                            HStack(spacing: 16) {
                                RemoteImage(source: .library(library), maxHeight: 120, placeholder: "books.vertical")
                                    .frame(width: 96, height: 54)
                                    .clipShape(.rect(cornerRadius: 6))
                                Text(library.name)
                                    .font(.headline)
                            }
                        }
                        .accessibilityIdentifier(LibraryListIdentifiers.row(library.id))
                    }
                    .accessibilityIdentifier(LibraryListIdentifiers.list)
                }
            }
            .navigationTitle("Libraries")
            .navigationDestination(for: Library.self) { library in
                LibraryDestination(library: library)
            }
            .navigationDestination(for: MediaItem.self) { item in
                MediaItemDestination(item: item)
            }
            .task {
                if case .idle = libraryService.libraries {
                    await libraryService.loadHome()
                }
            }
        }
    }
}

#if DEBUG
    #Preview("loaded") {
        LibraryListScreen().environment(\.libraryService, MockLibraryService.loaded())
    }

    #Preview("empty") {
        LibraryListScreen().environment(\.libraryService, MockLibraryService.empty())
    }

    #Preview("failure") {
        LibraryListScreen().environment(\.libraryService, MockLibraryService.failed())
    }
#endif
