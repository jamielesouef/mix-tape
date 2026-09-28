//  WalletShelfRow.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation
import SwiftUI

/// One titled, horizontally scrolling row of album thumbnails on `WalletsHomeScreen`. Tapping
/// the title opens the wallet's full CD-wallet view; tapping a thumbnail opens that album
/// directly. Editable wallets end with a "+" card that opens `AddAlbumsSheet`.
struct WalletShelfRow: View {
    // MARK: - Properties

    @Environment(\.walletsService) private var walletsService: WalletsService
    @Environment(\.musicPlayerService) private var music: MusicPlayerService
    @Environment(\.downloadsService) private var downloadsService: DownloadsService
    @State private var isPresentingAddAlbums = false
    @State private var isPresentingRename = false
    @State private var isPresentingDeleteConfirmation = false
    @State private var renameText = ""
    let wallet: Wallet
    let openAlbum: (MediaItem) -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(value: wallet) {
                Text(wallet.name)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(WalletsHomeIdentifiers.shelfRowTitle(wallet.id))
            .contextMenu {
                if wallet.isEditable {
                    Button("Rename", systemImage: "pencil") {
                        renameText = wallet.name
                        isPresentingRename = true
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        isPresentingDeleteConfirmation = true
                    }
                }
            }
            .alert("Rename Wallet", isPresented: $isPresentingRename) {
                TextField("Wallet Name", text: $renameText)
                Button("Cancel", role: .cancel) {}
                Button("Save") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)

                    guard trimmed.isEmpty == false else {
                        return
                    }

                    Task { await walletsService.renameWallet(wallet.id, to: trimmed) }
                }
            }
            .confirmationDialog(
                "Delete \(wallet.name)?",
                isPresented: $isPresentingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Wallet", role: .destructive) {
                    Task { await walletsService.deleteWallet(wallet.id) }
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(albums) { album in
                        Button { openAlbum(album) } label: {
                            AlbumThumbnail(
                                album: album,
                                isDownloaded: downloadsService.state(for: album.id) == .downloaded,
                                isPlaying: music.album?.id == album.id && music.isActive
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if wallet.isEditable {
                        Button { isPresentingAddAlbums = true } label: {
                            addAlbumsCard
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(WalletsHomeIdentifiers.addAlbumsCard(wallet.id))
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier(WalletsHomeIdentifiers.shelfRow(wallet.id))
        .sheet(isPresented: $isPresentingAddAlbums) {
            AddAlbumsSheet(wallet: wallet)
        }
    }

    // MARK: - Private

    private var albums: [MediaItem] {
        walletsService.albums(for: wallet)
    }

    private var addAlbumsCard: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(.tint, style: StrokeStyle(lineWidth: 2, dash: [6]))
            .background(.quaternary, in: .rect(cornerRadius: 8))
            .frame(width: 120, height: 120)
            .overlay {
                Image(systemName: "plus")
                    .font(.title)
                    .foregroundStyle(.tint)
            }
            .accessibilityLabel("Add albums to \(wallet.name)")
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        ScrollView {
            WalletShelfRow(wallet: MockWalletsService.previewWallet) { _ in }
        }
        .environment(\.walletsService, MockWalletsService.loaded())
        .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        ScrollView {
            WalletShelfRow(wallet: MockWalletsService.previewWallet) { _ in }
        }
        .environment(\.walletsService, MockWalletsService.empty())
    }

    #Preview("failure") {
        ScrollView {
            WalletShelfRow(
                wallet: Wallet(id: "personal-1", name: "Road Trip", kind: .personal),
                openAlbum: { _ in }
            )
        }
        .environment(\.walletsService, MockWalletsService.failed())
    }
#endif
