//  AlbumGridIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public enum AlbumGridIdentifiers {
    public static let grid = "albumGrid.grid"

    public static func cell(_ albumID: String) -> String {
        "albumGrid.cell.\(albumID)"
    }
}
