//  AddAlbumsSheet.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import SwiftUI

/// Lets a listener add albums from the library to one of their personal wallets. Removing an
/// album from a personal wallet happens from the wallet itself via swipe-to-remove, not here.
struct AddAlbumsSheet: View {
    // MARK: - Properties

    @Environment(\.walletsService) private var walletsService: WalletsService
    @Environment(\.dismiss) private var dismiss
    let wallet: Wallet

    // MARK: - Initialization

    init(wallet: Wallet) {
        self.wallet = wallet
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List(walletsService.allAlbums) { album in
                Button {
                    Task {
                        if isInWallet(album) {
                            await walletsService.removeAlbum(album.id, fromWallet: wallet.id)
                        } else {
                            await walletsService.addAlbum(album.id, toWallet: wallet.id)
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        RemoteImage(
                            source: .item(album, .primary),
                            maxHeight: 120,
                            placeholder: "music.note"
                        )
                        .frame(width: 44, height: 44)
                        .clipShape(.rect(cornerRadius: 6))
                        VStack(alignment: .leading) {
                            Text(album.name)
                            Text(album.albumArtist ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isInWallet(album) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .accessibilityIdentifier(WalletIdentifiers.addAlbumRow(album.id))
            }
            .navigationTitle("Add Albums")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier(WalletIdentifiers.addAlbumsDoneButton)
                }
            }
        }
    }

    // MARK: - Private

    private func isInWallet(_ album: MediaItem) -> Bool {
        walletsService.albums(for: wallet).contains { $0.id == album.id }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        AddAlbumsSheet(wallet: MockWalletsService.previewWallet)
            .environment(\.walletsService, MockWalletsService.loaded())
            .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        AddAlbumsSheet(wallet: MockWalletsService.previewWallet)
            .environment(\.walletsService, MockWalletsService.empty())
    }

    #Preview("failure") {
        AddAlbumsSheet(wallet: MockWalletsService.previewWallet)
            .environment(\.walletsService, MockWalletsService.failed())
    }
#endif
