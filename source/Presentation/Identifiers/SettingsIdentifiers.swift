//  SettingsIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

enum SettingsIdentifiers {
    static let serverNameLabel = "settings.serverNameLabel"
    static let userNameLabel = "settings.userNameLabel"
    static let signOutButton = "settings.signOutButton"
    static let refreshLibraryButton = "settings.refreshLibraryButton"
    static let albumCountLabel = "settings.albumCountLabel"
    static let albumOrderPicker = "settings.albumOrderPicker"
    static let whenAlbumEndsPicker = "settings.whenAlbumEndsPicker"
    static let streamingQualityPicker = "settings.streamingQualityPicker"
    static let downloadsSectionLink = "settings.downloadsSectionLink"
    static let downloadsWiFiOnlyToggle = "settings.downloadsWiFiOnlyToggle"
    static let downloadsStorageLabel = "settings.downloadsStorageLabel"
    static let removeAllDownloadsButton = "settings.removeAllDownloadsButton"

    static func downloadRow(_ albumID: String) -> String {
        "settings.downloadRow.\(albumID)"
    }
}
