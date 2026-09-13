//  LibraryTabScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(tvOS)
    import MixtapeDomain
    import MixtapeServices
    import SwiftUI

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
                        switch LibraryTabResolution(kind: kind, in: libraries) {
                        case let .one(library):
                            LibraryDestination(library: library)
                        case let .several(libraries):
                            LibraryKindListScreen(libraries: libraries)
                        case .none:
                            ContentUnavailableView("No \(name) library", systemImage: symbol, description: Text("Add a \(name) library to this Jellyfin user to see it here."))
                                .accessibilityIdentifier(LibraryTabIdentifiers.emptyLabel(name))
                        }
                    }
                }
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
            .fullScreenCover(isPresented: $showNowPlaying) {
                NowPlayingScreen()
            }
            .onChange(of: music.isActive) { _, active in
                if active == false {
                    showNowPlaying = false
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

    #if DEBUG
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
#endif
