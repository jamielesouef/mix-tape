//  HomeIdentifiers.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public enum HomeIdentifiers {
    public static let continueWatchingRow = "home.continueWatchingRow"
    public static let emptyLabel = "home.emptyLabel"

    public static func card(_ itemID: String) -> String {
        "home.card.\(itemID)"
    }
}
