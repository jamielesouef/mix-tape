//  WalletIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

public enum WalletIdentifiers {
    public static let pager = "wallet.pager"
    public static let pageIndicator = "wallet.pageIndicator"
    public static let emptyLabel = "wallet.emptyLabel"
    public static let retryButton = "wallet.retryButton"

    public static func page(_ index: Int) -> String {
        "wallet.page.\(index)"
    }

    public static func sleeve(_ albumID: String) -> String {
        "wallet.sleeve.\(albumID)"
    }
}
