//  WalletsService+Placeholder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

extension WalletsService {
    static let placeholder: WalletsService = {
        #if DEBUG
            return MockWalletsService.empty()
        #else
            let store = PlaceholderWalletsStore()
            return WalletsService(
                libraryService: .placeholder,
                downloadsService: .placeholder,
                settingsService: .placeholder,
                loadPersonalWallets: LoadPersonalWalletsUseCase(store: store),
                savePersonalWallets: SavePersonalWalletsUseCase(store: store),
                loadRandomWalletMode: LoadRandomWalletModeUseCase(store: store),
                saveRandomWalletMode: SaveRandomWalletModeUseCase(store: store)
            )
        #endif
    }()
}
