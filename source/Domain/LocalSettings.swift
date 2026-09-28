//  LocalSettings.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

struct LocalSettings: Sendable, Equatable {
    var albumOrder: AlbumOrder = .title
    var whenAlbumEnds: WhenAlbumEndsPreference = .stopAfterAlbum
    var streamingQuality: StreamingQuality = .automatic
    var downloadsWiFiOnly = true
}
