//  WalletIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

enum WalletIdentifiers {
    static let pager = "wallet.pager"
    static let pageIndicator = "wallet.pageIndicator"
    static let emptyLabel = "wallet.emptyLabel"
    static let retryButton = "wallet.retryButton"

    static func page(_ index: Int) -> String {
        "wallet.page.\(index)"
    }

    static func sleeve(_ albumID: String) -> String {
        "wallet.sleeve.\(albumID)"
    }
}
