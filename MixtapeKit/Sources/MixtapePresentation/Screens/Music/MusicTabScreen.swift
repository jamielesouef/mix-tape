//  MusicTabScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// The Music tab: the album grid of the first music library. The iOS wallet replaces the grid in
/// slice 010; further music libraries stay reachable from the Libraries tab.
public struct MusicTabScreen: View {
    @Environment(\.libraryService) private var libraryService

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                switch libraryService.libraries {
                case .idle, .loading:
                    ProgressView()
                case let .failed(error):
                    RetryView(error: error) { await libraryService.loadHome() }
                case let .loaded(libraries):
                    if let music = libraries.first(where: { $0.kind == .music }) {
                        AlbumGrid(library: music)
                    } else {
                        ContentUnavailableView("No music library", systemImage: "music.note", description: Text("Add a music library to this Jellyfin user to see albums here."))
                            .accessibilityIdentifier(MusicTabIdentifiers.emptyLabel)
                    }
                }
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

#Preview("loaded") {
    MusicTabScreen().environment(\.libraryService, MockLibraryService.loaded())
}

#Preview("empty") {
    MusicTabScreen().environment(\.libraryService, MockLibraryService.empty())
}

#Preview("failure") {
    MusicTabScreen().environment(\.libraryService, MockLibraryService.failed())
}
