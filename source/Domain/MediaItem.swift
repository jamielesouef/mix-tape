//  MediaItem.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct MediaItem: Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: MediaKind
    let overview: String?
    let productionYear: Int?
    let runtime: Duration?
    let indexNumber: Int?
    let parentIndexNumber: Int?
    let albumArtist: String?
    let primaryImageTag: String?
    let backdropImageTag: String?
    let parentPrimaryImageTag: String?
    let albumID: String?
    let container: String?
    let playback: PlaybackState

    init(
        id: String, name: String, kind: MediaKind, overview: String?, productionYear: Int?, runtime: Duration?,
        indexNumber: Int?, parentIndexNumber: Int?, albumArtist: String?, primaryImageTag: String?,
        backdropImageTag: String?, parentPrimaryImageTag: String?, albumID: String? = nil, container: String? = nil,
        playback: PlaybackState,
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.overview = overview
        self.productionYear = productionYear
        self.runtime = runtime
        self.indexNumber = indexNumber
        self.parentIndexNumber = parentIndexNumber
        self.albumArtist = albumArtist
        self.primaryImageTag = primaryImageTag
        self.backdropImageTag = backdropImageTag
        self.parentPrimaryImageTag = parentPrimaryImageTag
        self.albumID = albumID
        self.container = container
        self.playback = playback
    }
}
