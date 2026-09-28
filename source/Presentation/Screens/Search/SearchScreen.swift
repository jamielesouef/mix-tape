//  SearchScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import SwiftUI

struct SearchScreen: View {
    // MARK: - Properties

    @Environment(\.searchService) private var searchService: SearchService
    @Environment(\.libraryService) private var libraryService: LibraryService
    @Environment(\.musicPlayerService) private var music: MusicPlayerService
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var pulledAlbum: MediaItem?

    init() {}

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch searchService.result {
                case .idle:
                    ContentUnavailableView("Search Your Library", systemImage: "magnifyingglass")

                case .loading:
                    ProgressView()

                case let .failed(error):
                    RetryView(error: error) { searchService.updateQuery(searchService.query) }

                case let .loaded(result) where result.isEmpty:
                    ContentUnavailableView.search
                        .accessibilityIdentifier(SearchIdentifiers.emptyLabel)

                case let .loaded(result):
                    List {
                        if searchService.isOffline {
                            Text("Offline — showing downloaded music only")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier(SearchIdentifiers.offlineLabel)
                        }
                        if result.albums.isEmpty == false {
                            Section("Albums") {
                                ForEach(result.albums) { album in
                                    Button { pulledAlbum = album } label: {
                                        AlbumResultRow(album: album)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier(SearchIdentifiers.albumRow(album.id))
                                }
                            }
                        }
                        if result.tracks.isEmpty == false {
                            Section("Tracks") {
                                ForEach(result.tracks) { track in
                                    Button { Task { await play(track) } } label: {
                                        TrackResultRow(track: track, albumTitle: albumTitle(for: track))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier(SearchIdentifiers.trackRow(track.id))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Albums and tracks")
            .onChange(of: query) { _, text in searchService.updateQuery(text) }
            .navigationDestination(item: $pulledAlbum) { album in
                AlbumDetailScreen(album: album)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        searchService.clear()
                        dismiss()
                    }
                    .accessibilityIdentifier(SearchIdentifiers.doneButton)
                }
            }
        }
    }

    // MARK: - Private

    private func albumTitle(for track: MediaItem) -> String? {
        guard let albumID = track.albumID,
              case let .loaded(albums) = searchService.result,
              let album = albums.albums.first(where: { $0.id == albumID })
        else {
            return nil
        }

        return album.name
    }

    /// Loads the track's full album so playback continues through the rest of it, per
    /// "selecting a track plays from that track through the rest of its album."
    private func play(_ track: MediaItem) async {
        guard let albumID = track.albumID else {
            return
        }

        await libraryService.loadDetail(id: albumID)
        await libraryService.loadTracks(albumID: albumID)

        guard case let .loaded(album) = libraryService.details[albumID],
              case let .loaded(tracks) = libraryService.tracks[albumID],
              let index = tracks.firstIndex(where: { $0.id == track.id })
        else {
            return
        }

        await music.play(album: album, tracks: tracks, startingAt: index)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        SearchScreen()
            .environment(\.searchService, MockSearchService.loaded())
            .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        SearchScreen().environment(\.searchService, MockSearchService.empty())
    }

    #Preview("failure") {
        SearchScreen().environment(\.searchService, MockSearchService.failed())
    }
#endif
