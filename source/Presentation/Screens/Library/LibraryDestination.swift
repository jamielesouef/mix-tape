//  LibraryDestination.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import SwiftUI

struct LibraryDestination: View {
    // MARK: - Properties

    let library: Library

    // MARK: - Body

    var body: some View {
        switch library.kind {
        case .music:
            WalletScreen(wallet: Self.libraryWallet(for: library))
        case .unsupported:
            ContentUnavailableView(library.name, systemImage: "questionmark.folder")
        }
    }

    // MARK: - Private

    /// Matches the id `WalletsService` assigns its per-library wallet, so this still resolves
    /// correctly if anything ever navigates here again.
    private static func libraryWallet(for library: Library) -> Wallet {
        Wallet(id: "library-\(library.id)", name: library.name, kind: .library(id: library.id))
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        NavigationStack {
            LibraryDestination(library: MockMedia.libraries[0])
        }
        .environment(\.walletsService, MockWalletsService.loaded())
    }

    #Preview("empty") {
        NavigationStack {
            LibraryDestination(library: MockMedia.libraries[1])
        }
    }

    #Preview("failure") {
        NavigationStack {
            LibraryDestination(library: MockMedia.libraries[0])
        }
        .environment(\.walletsService, MockWalletsService.failed())
    }
#endif
