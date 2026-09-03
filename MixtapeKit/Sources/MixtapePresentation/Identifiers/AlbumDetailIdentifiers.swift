//  AlbumDetailIdentifiers.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public enum AlbumDetailIdentifiers {
    public static let titleLabel = "albumDetail.titleLabel"
    public static let playButton = "albumDetail.playButton"

    public static func trackRow(_ itemID: String) -> String {
        "albumDetail.trackRow.\(itemID)"
    }
}
