//  AlbumDetailIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

enum AlbumDetailIdentifiers {
    static let titleLabel = "albumDetail.titleLabel"
    static let playButton = "albumDetail.playButton"

    static func trackRow(_ itemID: String) -> String {
        "albumDetail.trackRow.\(itemID)"
    }
}
