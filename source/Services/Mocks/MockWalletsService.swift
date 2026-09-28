//  MockWalletsService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

#if DEBUG

    @MainActor
    enum MockWalletsService {
        static let previewWallet = Wallet(
            id: "library-lib-music",
            name: "Music",
            kind: .library(id: "lib-music"),
            albumIDs: MockMedia.albums.map(\.id)
        )

        static func make(
            libraryService: LibraryService = MockLibraryService.loaded(),
            downloadsService: DownloadsService = MockDownloadsService.idle(),
            settingsService: SettingsService = MockSettingsService.make(),
            wallets: LoadState<[Wallet]> = .idle,
            albumsByWalletID: [String: [MediaItem]] = [:]
        ) -> WalletsService {
            let store = MockWalletsStore()

            return WalletsService(
                libraryService: libraryService,
                downloadsService: downloadsService,
                settingsService: settingsService,
                loadPersonalWallets: LoadPersonalWalletsUseCase(store: store),
                savePersonalWallets: SavePersonalWalletsUseCase(store: store),
                loadRandomWalletMode: LoadRandomWalletModeUseCase(store: store),
                saveRandomWalletMode: SaveRandomWalletModeUseCase(store: store),
                wallets: wallets,
                albumsByWalletID: albumsByWalletID
            )
        }

        static func loaded() -> WalletsService {
            let libraryWallet = previewWallet
            let personalWallet = Wallet(
                id: "personal-1",
                name: "Road Trip",
                kind: .personal,
                albumIDs: [MockMedia.albums[0].id]
            )

            return make(
                wallets: .loaded([libraryWallet, personalWallet]),
                albumsByWalletID: [
                    libraryWallet.id: MockMedia.albums,
                    personalWallet.id: [MockMedia.albums[0]]
                ]
            )
        }

        static func empty() -> WalletsService {
            make(wallets: .loaded([]))
        }

        static func failed() -> WalletsService {
            make(wallets: .failed(.serverUnreachable))
        }
    }
#endif
