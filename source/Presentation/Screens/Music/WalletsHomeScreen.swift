//  WalletsHomeScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import SwiftUI

/// The wallet shelf: one titled, horizontally scrolling row per wallet — personal, generated,
/// per-library, and Downloaded. The Music tab's root.
struct WalletsHomeScreen: View {
    // MARK: - Properties

    @Environment(\.walletsService) private var walletsService: WalletsService
    @Environment(\.sessionService) private var sessionService: SessionService
    @Environment(\.settingsService) private var settingsService: SettingsService
    @State private var isPresentingCreateWallet = false
    @State private var isPresentingSearch = false
    @State private var isPresentingSettings = false
    @State private var pulledAlbum: MediaItem?
    @State private var albumOrder = AlbumOrder.title

    init() {}

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch walletsService.wallets {
                case .idle,
                     .loading:
                    ProgressView()
                case let .failed(error):
                    RetryView(error: error) { await walletsService.loadWallets() }
                case let .loaded(wallets) where wallets.isEmpty:
                    ContentUnavailableView(
                        "No wallets yet",
                        systemImage: "rectangle.stack",
                        description: Text("Add a music library on the server to see wallets here.")
                    )
                    .accessibilityIdentifier(WalletsHomeIdentifiers.emptyLabel)
                case let .loaded(wallets):
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            ForEach(wallets) { wallet in
                                WalletShelfRow(wallet: wallet) { pulledAlbum = $0 }
                            }

                            Button("New Wallet", systemImage: "plus") {
                                isPresentingCreateWallet = true
                            }
                            .padding(.horizontal)
                            .accessibilityIdentifier(WalletsHomeIdentifiers.createWalletButton)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Wallets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    overflowMenu
                }
            }
            .navigationDestination(for: Wallet.self) { wallet in
                WalletScreen(wallet: wallet)
            }
            .navigationDestination(item: $pulledAlbum) { album in
                AlbumDetailScreen(album: album)
            }
            .navigationDestination(isPresented: $isPresentingSettings) {
                SettingsScreen()
            }
            .sheet(isPresented: $isPresentingCreateWallet) {
                CreateWalletSheet()
            }
            .sheet(isPresented: $isPresentingSearch) {
                SearchScreen()
            }
            .task {
                albumOrder = settingsService.settings.albumOrder

                if case .idle = walletsService.wallets {
                    await walletsService.loadWallets()
                }
            }
            .onChange(of: albumOrder) { _, order in
                settingsService.setAlbumOrder(order)
                Task { await walletsService.loadWallets() }
            }
        }
    }

    // MARK: - Private

    private var overflowMenu: some View {
        Menu {
            Button("Search", systemImage: "magnifyingglass") {
                isPresentingSearch = true
            }
            .accessibilityIdentifier(WalletsHomeIdentifiers.searchMenuItem)

            Picker("Album Order", selection: $albumOrder) {
                Text("Title").tag(AlbumOrder.title)
                Text("Artist").tag(AlbumOrder.artist)
                Text("Random").tag(AlbumOrder.random)
            }

            Button("Settings", systemImage: "gear") {
                isPresentingSettings = true
            }
            .accessibilityIdentifier(WalletsHomeIdentifiers.settingsMenuItem)

            Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                sessionService.signOut()
            }
            .accessibilityIdentifier(WalletsHomeIdentifiers.signOutMenuItem)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityIdentifier(WalletsHomeIdentifiers.overflowMenu)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        WalletsHomeScreen()
            .environment(\.walletsService, MockWalletsService.loaded())
            .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        WalletsHomeScreen().environment(\.walletsService, MockWalletsService.empty())
    }

    #Preview("failure") {
        WalletsHomeScreen().environment(\.walletsService, MockWalletsService.failed())
    }
#endif
