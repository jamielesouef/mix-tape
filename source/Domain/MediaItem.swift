//  MediaItem.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct MediaItem: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let kind: MediaKind
    public let overview: String?
    public let productionYear: Int?
    public let runtime: Duration?
    public let indexNumber: Int?
    public let parentIndexNumber: Int?
    public let seriesName: String?
    public let albumArtist: String?
    public let primaryImageTag: String?
    public let backdropImageTag: String?
    public let parentPrimaryImageTag: String?
    public let albumID: String?
    public let container: String?
    public let playback: PlaybackState

    public init(id: String, name: String, kind: MediaKind, overview: String?, productionYear: Int?, runtime: Duration?, indexNumber: Int?, parentIndexNumber: Int?, seriesName: String?, albumArtist: String?, primaryImageTag: String?, backdropImageTag: String?, parentPrimaryImageTag: String?, albumID: String? = nil, container: String? = nil, playback: PlaybackState) {
        self.id = id
        self.name = name
        self.kind = kind
        self.overview = overview
        self.productionYear = productionYear
        self.runtime = runtime
        self.indexNumber = indexNumber
        self.parentIndexNumber = parentIndexNumber
        self.seriesName = seriesName
        self.albumArtist = albumArtist
        self.primaryImageTag = primaryImageTag
        self.backdropImageTag = backdropImageTag
        self.parentPrimaryImageTag = parentPrimaryImageTag
        self.albumID = albumID
        self.container = container
        self.playback = playback
    }
}
