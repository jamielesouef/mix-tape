//  LibraryTabIdentifiers.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

public enum LibraryTabIdentifiers {
    public static let nowPlayingButton = "libraryTab.nowPlayingButton"

    public static func emptyLabel(_ kind: String) -> String {
        "libraryTab.emptyLabel.\(kind)"
    }
}
