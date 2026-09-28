//  SettingsScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import SwiftUI

struct SettingsScreen: View {
    // MARK: - Properties

    @Environment(\.sessionService) private var sessionService: SessionService
    @Environment(\.settingsService) private var settingsService: SettingsService
    @Environment(\.libraryService) private var libraryService: LibraryService
    @Environment(\.downloadsService) private var downloadsService: DownloadsService
    @State private var isPresentingSignOutConfirmation = false
    @State private var albumOrder = AlbumOrder.title
    @State private var whenAlbumEnds = WhenAlbumEndsPreference.stopAfterAlbum
    @State private var streamingQuality = StreamingQuality.automatic

    init() {}

    // MARK: - Body

    var body: some View {
        List {
            Section("Server") {
                LabeledContent("Name", value: sessionService.serverIdentity?.name ?? serverHost)
                    .accessibilityIdentifier(SettingsIdentifiers.serverNameLabel)
                LabeledContent("User", value: userName)
                    .accessibilityIdentifier(SettingsIdentifiers.userNameLabel)
                if let albumCount {
                    LabeledContent("Albums", value: albumCount.formatted())
                        .accessibilityIdentifier(SettingsIdentifiers.albumCountLabel)
                }
                Button("Refresh Library") {
                    Task { await libraryService.refresh() }
                }
                .accessibilityIdentifier(SettingsIdentifiers.refreshLibraryButton)
            }

            Section("Browsing") {
                Picker("Album Order", selection: $albumOrder) {
                    Text("Title").tag(AlbumOrder.title)
                    Text("Artist").tag(AlbumOrder.artist)
                    Text("Random").tag(AlbumOrder.random)
                }
                .accessibilityIdentifier(SettingsIdentifiers.albumOrderPicker)

                Picker("When an Album Ends", selection: $whenAlbumEnds) {
                    Text("Stop After Album").tag(WhenAlbumEndsPreference.stopAfterAlbum)
                    Text("Continue Through Wallet").tag(WhenAlbumEndsPreference.continueThroughWallet)
                }
                .accessibilityIdentifier(SettingsIdentifiers.whenAlbumEndsPicker)
            }

            Section("Playback") {
                Picker("Streaming Quality", selection: $streamingQuality) {
                    Text("Automatic").tag(StreamingQuality.automatic)
                    Text("High").tag(StreamingQuality.high)
                    Text("Medium").tag(StreamingQuality.medium)
                    Text("Low").tag(StreamingQuality.low)
                }
                .accessibilityIdentifier(SettingsIdentifiers.streamingQualityPicker)
            }

            Section("Downloads") {
                NavigationLink("Manage Downloads") {
                    DownloadsSettingsScreen()
                }
                .accessibilityIdentifier(SettingsIdentifiers.downloadsSectionLink)
            }

            Section {
                Button("Sign Out", role: .destructive) { signOutTapped() }
                    .accessibilityIdentifier(SettingsIdentifiers.signOutButton)
            }
        }
        .navigationTitle("Settings")
        .task {
            albumOrder = settingsService.settings.albumOrder
            whenAlbumEnds = settingsService.settings.whenAlbumEnds
            streamingQuality = settingsService.settings.streamingQuality
        }
        .onChange(of: albumOrder) { _, order in settingsService.setAlbumOrder(order) }
        .onChange(of: whenAlbumEnds) { _, preference in
            settingsService.setWhenAlbumEnds(preference)
        }
        .onChange(of: streamingQuality) { _, quality in
            settingsService.setStreamingQuality(quality)
        }
        .confirmationDialog(
            "Downloaded albums will be removed from this device when you sign out.",
            isPresented: $isPresentingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out and Remove Downloads", role: .destructive) {
                Task {
                    await downloadsService.removeAll()
                    sessionService.signOut()
                }
            }
        }
    }

    // MARK: - Private

    private var userName: String {
        sessionService.currentSession?.userName ?? "—"
    }

    private var serverHost: String {
        sessionService.currentSession?.serverURL.host() ?? "—"
    }

    private var albumCount: Int? {
        for state in libraryService.pages.values {
            if case let .loaded(page) = state {
                return page.totalCount
            }
        }

        return nil
    }

    private func signOutTapped() {
        if downloadsService.downloadedAlbumIDs.isEmpty {
            sessionService.signOut()
        } else {
            isPresentingSignOutConfirmation = true
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        NavigationStack {
            SettingsScreen()
        }
        .environment(\.sessionService, MockSessionService.signedIn())
        .environment(\.settingsService, MockSettingsService.make())
        .environment(\.downloadsService, MockDownloadsService.downloaded())
        .environment(\.walletsService, MockWalletsService.loaded())
    }

    #Preview("empty") {
        NavigationStack {
            SettingsScreen()
        }
        .environment(\.sessionService, MockSessionService.signedOut())
        .environment(\.downloadsService, MockDownloadsService.idle())
        .environment(\.walletsService, MockWalletsService.empty())
    }

    #Preview("failure") {
        NavigationStack {
            SettingsScreen()
        }
        .environment(\.sessionService, MockSessionService.failed(.sessionExpired))
        .environment(\.downloadsService, MockDownloadsService.idle())
        .environment(\.walletsService, MockWalletsService.empty())
    }
#endif
