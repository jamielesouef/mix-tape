//  WalletsHomeIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

enum WalletsHomeIdentifiers {
    static let emptyLabel = "walletsHome.emptyLabel"
    static let createWalletButton = "walletsHome.createWalletButton"
    static let overflowMenu = "walletsHome.overflowMenu"
    static let searchMenuItem = "walletsHome.searchMenuItem"
    static let settingsMenuItem = "walletsHome.settingsMenuItem"
    static let signOutMenuItem = "walletsHome.signOutMenuItem"

    static func shelfRow(_ walletID: String) -> String {
        "walletsHome.shelfRow.\(walletID)"
    }

    static func shelfRowTitle(_ walletID: String) -> String {
        "walletsHome.shelfRowTitle.\(walletID)"
    }

    static func addAlbumsCard(_ walletID: String) -> String {
        "walletsHome.addAlbumsCard.\(walletID)"
    }
}
