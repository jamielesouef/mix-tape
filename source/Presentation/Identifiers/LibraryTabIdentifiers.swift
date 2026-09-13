//  LibraryTabIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

enum LibraryTabIdentifiers {
    static let nowPlayingButton = "libraryTab.nowPlayingButton"
    static let libraryList = "libraryTab.libraryList"

    static func libraryRow(_ libraryID: String) -> String {
        "libraryTab.libraryRow.\(libraryID)"
    }

    static func emptyLabel(_ kind: String) -> String {
        "libraryTab.emptyLabel.\(kind)"
    }
}
