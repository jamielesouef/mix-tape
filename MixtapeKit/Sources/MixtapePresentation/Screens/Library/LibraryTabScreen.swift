//  LibraryTabScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(tvOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

    /// One tvOS tab per library kind (decision 26): resolves the first library of `kind` and hosts
    /// its shelf. The Music tab also carries a "Now Playing" button while music is active — the
    /// Siri Remote has no skip buttons, so `NowPlayingScreen` is the only route to next/previous.
    public struct LibraryTabScreen: View {
        @Environment(\.libraryService) private var libraryService
        @Environment(\.musicPlayerService) private var music
        @State private var showNowPlaying = false
        let kind: LibraryKind

        public init(kind: LibraryKind) {
            self.kind = kind
        }

        public var body: some View {
            NavigationStack {
                Group {
                    switch libraryService.libraries {
                    case .idle, .loading:
                        ProgressView()
                    case let .failed(error):
                        RetryView(error: error) { await libraryService.loadHome() }
                    case let .loaded(libraries):
                        if let library = libraries.first(where: { $0.kind == kind }) {
                            LibraryDestination(library: library)
                        } else {
                            ContentUnavailableView("No \(name) library", systemImage: symbol, description: Text("Add a \(name) library to this Jellyfin user to see it here."))
                                .accessibilityIdentifier(LibraryTabIdentifiers.emptyLabel(name))
                        }
                    }
                }
                // An overlay, not a toolbar item (Section 6). The full-width focus section lets an
                // up-swipe from any album card reach the button, which sits above no card of its own.
                .overlay(alignment: .top) {
                    if kind == .music, music.isActive {
                        HStack {
                            Spacer()
                            Button("Now Playing", systemImage: "waveform") { showNowPlaying = true }
                                .accessibilityIdentifier(LibraryTabIdentifiers.nowPlayingButton)
                        }
                        .padding(60)
                        .focusSection()
                    }
                }
                .navigationDestination(isPresented: $showNowPlaying) {
                    NowPlayingScreen()
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

        private var name: String {
            switch kind {
            case .movies: "movies"
            case .tvShows: "shows"
            case .music: "music"
            case .unsupported: "media"
            }
        }

        private var symbol: String {
            switch kind {
            case .movies: "film"
            case .tvShows: "tv"
            case .music: "music.note"
            case .unsupported: "questionmark.folder"
            }
        }
    }

    #Preview("loaded") {
        LibraryTabScreen(kind: .movies).environment(\.libraryService, MockLibraryService.loaded())
    }

    #Preview("empty") {
        LibraryTabScreen(kind: .music).environment(\.libraryService, MockLibraryService.empty())
    }

    #Preview("failure") {
        LibraryTabScreen(kind: .tvShows).environment(\.libraryService, MockLibraryService.failed())
    }
#endif
