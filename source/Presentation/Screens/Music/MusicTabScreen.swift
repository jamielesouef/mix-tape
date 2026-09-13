//  MusicTabScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import SwiftUI

struct MusicTabScreen: View {
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
                case let .loaded(libraries):
                    if let music = libraries.first(where: { $0.kind == .music }) {
                        WalletScreen(library: music)
                    } else {
                        ContentUnavailableView("No music library", systemImage: "music.note", description: Text("Add a music library to this Jellyfin user to see albums here."))
                            .accessibilityIdentifier(MusicTabIdentifiers.emptyLabel)
                    }
                }
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
        MusicTabScreen().environment(\.libraryService, MockLibraryService.loaded())
    }

    #Preview("empty") {
        MusicTabScreen().environment(\.libraryService, MockLibraryService.empty())
    }

    #Preview("failure") {
        MusicTabScreen().environment(\.libraryService, MockLibraryService.failed())
    }
#endif
