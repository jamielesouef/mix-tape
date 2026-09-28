//  AlbumDetailIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

enum AlbumDetailIdentifiers {
    static let titleLabel = "albumDetail.titleLabel"
    static let playButton = "albumDetail.playButton"
    static let playPauseButton = "albumDetail.playPauseButton"
    static let playReplaceButton = "albumDetail.playReplaceButton"
    static let stopButton = "albumDetail.stopButton"
    static let downloadButton = "albumDetail.downloadButton"

    static func trackRow(_ itemID: String) -> String {
        "albumDetail.trackRow.\(itemID)"
    }
}
