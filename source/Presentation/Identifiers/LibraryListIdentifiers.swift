//  LibraryListIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

enum LibraryListIdentifiers {
    static let list = "libraryList.list"

    static func row(_ libraryID: String) -> String {
        "libraryList.row.\(libraryID)"
    }
}
