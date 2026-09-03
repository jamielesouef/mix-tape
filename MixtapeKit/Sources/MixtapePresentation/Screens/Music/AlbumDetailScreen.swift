//  AlbumDetailScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeServices
import SwiftUI

/// Art, album artist, year, track list, Play. Play renders and does nothing until slice 009.
public struct AlbumDetailScreen: View {
    @Environment(\.libraryService) private var libraryService
    let album: MediaItem

    public init(album: MediaItem) {
        self.album = album
    }

    public var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    RemoteImage(source: .item(album, .primary), maxHeight: 600, placeholder: "music.note")
                        .aspectRatio(1, contentMode: .fit)
                        .frame(maxWidth: 320)
                        .clipShape(.rect(cornerRadius: 12))
                    Text(album.name)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(AlbumDetailIdentifiers.titleLabel)
                    Text([album.albumArtist, album.productionYear.map(String.init)].compactMap(\.self).joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    // Wired to `MusicPlayerService` in slice 009.
                    Button("Play", systemImage: "play.fill") {}
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier(AlbumDetailIdentifiers.playButton)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            Section("Tracks") {
                switch libraryService.tracks[album.id] {
                case .none, .idle, .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                case let .failed(error):
                    RetryView(error: error) { await libraryService.loadTracks(albumID: album.id) }
                case let .loaded(tracks) where tracks.isEmpty:
                    Text("No tracks")
                        .foregroundStyle(.secondary)
                case let .loaded(tracks):
                    ForEach(tracks) { track in
                        TrackRow(track: track)
                            .accessibilityIdentifier(AlbumDetailIdentifiers.trackRow(track.id))
                    }
                }
            }
        }
        .navigationTitle(album.name)
        .task { await libraryService.loadTracks(albumID: album.id) }
    }
}

#Preview("loaded") {
    NavigationStack {
        AlbumDetailScreen(album: MockMedia.albums[0])
    }
    .environment(\.libraryService, MockLibraryService.loaded())
}

#Preview("empty") {
    NavigationStack {
        AlbumDetailScreen(album: MockMedia.albums[0])
    }
    .environment(\.libraryService, MockLibraryService.empty())
}

#Preview("failure") {
    NavigationStack {
        AlbumDetailScreen(album: MockMedia.albums[0])
    }
    .environment(\.libraryService, MockLibraryService.failed())
}
