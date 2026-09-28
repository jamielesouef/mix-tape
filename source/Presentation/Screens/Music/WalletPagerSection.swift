//  WalletPagerSection.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import SwiftUI

/// The CD-wallet pager itself — pages of sleeves, the footer, the toolbar's Add Albums and
/// random-wallet actions. Split out of `WalletScreen` so the type checker sees the deeply
/// nested `TabView`/`Grid` tree in one pass rather than folded into a much longer chain.
struct WalletPagerSection: View {
    // MARK: - Properties

    @Environment(\.walletsService) private var walletsService: WalletsService
    @State private var randomMode = RandomWalletMode.fullyRandom
    @Binding var pageIndex: Int
    @Binding var isPresentingAddAlbums: Bool
    let wallet: Wallet
    let pulsingAlbumID: String?
    let namespace: Namespace.ID
    let columns: Int
    let onSelect: (MediaItem) -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $pageIndex) {
                ForEach(0 ..< pager.pageCount, id: \.self) { page in
                    WalletPage(
                        albums: pager.albums(onPage: page),
                        columns: columns,
                        pulsingAlbumID: pulsingAlbumID,
                        namespace: namespace
                    ) { onSelect($0) }
                        .tag(page)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier(WalletIdentifiers.page(page))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .accessibilityIdentifier(WalletIdentifiers.pager)

            WalletFooter(phase: phase, pageIndex: pageIndex, pageCount: pager.pageCount) {
                Task { await walletsService.loadWallets() }
            }
        }
        .padding(.bottom)
        .navigationTitle(wallet.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if wallet.isEditable {
                    Button("Add Albums", systemImage: "plus") { isPresentingAddAlbums = true }
                }
                if Self.isRandom(wallet) {
                    randomWalletMenu
                }
            }
        }
        .sheet(isPresented: $isPresentingAddAlbums) {
            AddAlbumsSheet(wallet: wallet)
        }
        .onAppear { randomMode = walletsService.randomWalletMode }
        .onChange(of: randomMode) { _, mode in
            Task { await walletsService.setRandomWalletMode(mode) }
        }
    }

    // MARK: - Private

    private static func isRandom(_ wallet: Wallet) -> Bool {
        if case .random = wallet.kind {
            return true
        }
        return false
    }

    private var pager: WalletPager {
        WalletPager(albums: walletsService.albums(for: wallet), columns: columns)
    }

    private var phase: ContentPhase<[MediaItem]> {
        switch walletsService.wallets {
        case .idle,
             .loading:
            .loading
        case let .failed(error):
            .failed(error)
        case .loaded:
            pager.albums.isEmpty ? .empty : .loaded(pager.albums)
        }
    }

    private var randomWalletMenu: some View {
        Menu {
            Button("Regenerate", systemImage: "shuffle") {
                Task { await walletsService.regenerateRandomWallet() }
            }
            Picker("Selection", selection: $randomMode) {
                Text("Fully Random").tag(RandomWalletMode.fullyRandom)
                Text("Favour Least Played").tag(RandomWalletMode.favouringLeastPlayed)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        @Previewable @State var pageIndex = 0
        @Previewable @State var isPresentingAddAlbums = false
        @Previewable @Namespace var namespace

        WalletPagerSection(
            pageIndex: $pageIndex,
            isPresentingAddAlbums: $isPresentingAddAlbums,
            wallet: MockWalletsService.previewWallet,
            pulsingAlbumID: nil,
            namespace: namespace,
            columns: 2,
            onSelect: { _ in }
        )
        .environment(\.walletsService, MockWalletsService.loaded())
        .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        @Previewable @State var pageIndex = 0
        @Previewable @State var isPresentingAddAlbums = false
        @Previewable @Namespace var namespace

        WalletPagerSection(
            pageIndex: $pageIndex,
            isPresentingAddAlbums: $isPresentingAddAlbums,
            wallet: MockWalletsService.previewWallet,
            pulsingAlbumID: nil,
            namespace: namespace,
            columns: 2,
            onSelect: { _ in }
        )
        .environment(\.walletsService, MockWalletsService.empty())
    }

    #Preview("failure") {
        @Previewable @State var pageIndex = 0
        @Previewable @State var isPresentingAddAlbums = false
        @Previewable @Namespace var namespace

        WalletPagerSection(
            pageIndex: $pageIndex,
            isPresentingAddAlbums: $isPresentingAddAlbums,
            wallet: MockWalletsService.previewWallet,
            pulsingAlbumID: nil,
            namespace: namespace,
            columns: 2,
            onSelect: { _ in }
        )
        .environment(\.walletsService, MockWalletsService.failed())
    }
#endif
