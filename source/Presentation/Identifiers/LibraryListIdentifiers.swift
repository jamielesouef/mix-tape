//  LibraryListIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public enum LibraryListIdentifiers {
    public static let list = "libraryList.list"

    public static func row(_ libraryID: String) -> String {
        "libraryList.row.\(libraryID)"
    }
}
