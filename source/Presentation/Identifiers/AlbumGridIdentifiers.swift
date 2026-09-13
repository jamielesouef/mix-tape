//  AlbumGridIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

enum AlbumGridIdentifiers {
    static let grid = "albumGrid.grid"

    static func cell(_ albumID: String) -> String {
        "albumGrid.cell.\(albumID)"
    }
}
