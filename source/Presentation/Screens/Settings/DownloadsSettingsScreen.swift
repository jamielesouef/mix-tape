//  DownloadsSettingsScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation
import SwiftUI

/// The Downloads section of Settings: every album with a download of its own — downloaded,
/// active, waiting, or failed — its storage, and the Wi-Fi-only preference.
struct DownloadsSettingsScreen: View {
    // MARK: - Properties

    @Environment(\.downloadsService) private var downloadsService: DownloadsService
    @Environment(\.settingsService) private var settingsService: SettingsService
    @Environment(\.walletsService) private var walletsService: WalletsService
    @Environment(\.libraryService) private var libraryService: LibraryService
    @State private var bytesByAlbumID: [String: Int64] = [:]
    @State private var totalBytes: Int64 = 0
    @State private var isPresentingRemoveAllConfirmation = false
    @State private var wifiOnly = true

    init() {}

    // MARK: - Body

    var body: some View {
        List {
            Section {
                Toggle("Wi-Fi Only", isOn: $wifiOnly)
                    .accessibilityIdentifier(SettingsIdentifiers.downloadsWiFiOnlyToggle)
                LabeledContent("Storage Used", value: totalBytes.formatted(.byteCount(style: .file)))
                    .accessibilityIdentifier(SettingsIdentifiers.downloadsStorageLabel)
            }

            if albums.isEmpty {
                Section {
                    Text("No downloads yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Downloaded Albums") {
                    ForEach(albums) { album in
                        DownloadRow(
                            album: album,
                            state: downloadsService.state(for: album.id),
                            bytes: bytesByAlbumID[album.id]
                        ) {
                            Task {
                                await performAction(for: album)
                                await refreshBytes()
                            }
                        }
                    }
                }
            }

            Section {
                Button("Remove All Downloads", role: .destructive) {
                    isPresentingRemoveAllConfirmation = true
                }
                .disabled(albums.isEmpty)
                .accessibilityIdentifier(SettingsIdentifiers.removeAllDownloadsButton)
            }
        }
        .navigationTitle("Downloads")
        .task {
            wifiOnly = settingsService.settings.downloadsWiFiOnly
            await refreshBytes()
        }
        .onChange(of: wifiOnly) { _, enabled in settingsService.setDownloadsWiFiOnly(enabled) }
        .confirmationDialog(
            "Remove all downloads?",
            isPresented: $isPresentingRemoveAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove All Downloads", role: .destructive) {
                Task {
                    await downloadsService.removeAll()
                    await refreshBytes()
                }
            }
        }
    }

    // MARK: - Private

    private var albums: [MediaItem] {
        walletsService.allAlbums.filter { downloadsService.state(for: $0.id) != .notDownloaded }
    }

    private func performAction(for album: MediaItem) async {
        switch downloadsService.state(for: album.id) {
        case .notDownloaded:
            break
        case .waitingForWiFi,
             .downloading:
            await downloadsService.cancel(albumID: album.id)
        case .downloaded:
            await downloadsService.remove(albumID: album.id)
        case .failed:
            await libraryService.loadTracks(albumID: album.id)

            guard case let .loaded(tracks) = libraryService.tracks[album.id] else {
                return
            }

            await downloadsService.start(album: album, tracks: tracks)
        }
    }

    private func refreshBytes() async {
        totalBytes = await downloadsService.totalBytesOnDisk()

        for album in albums {
            bytesByAlbumID[album.id] = await downloadsService.bytesOnDisk(albumID: album.id)
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        NavigationStack {
            DownloadsSettingsScreen()
        }
        .environment(\.downloadsService, MockDownloadsService.downloaded())
        .environment(\.walletsService, MockWalletsService.loaded())
    }

    #Preview("empty") {
        NavigationStack {
            DownloadsSettingsScreen()
        }
        .environment(\.downloadsService, MockDownloadsService.idle())
        .environment(\.walletsService, MockWalletsService.empty())
    }

    #Preview("failure") {
        NavigationStack {
            DownloadsSettingsScreen()
        }
        .environment(
            \.downloadsService,
            MockDownloadsService.make(downloads: ["album-1": .failed(.serverUnreachable)])
        )
        .environment(\.walletsService, MockWalletsService.loaded())
    }
#endif
