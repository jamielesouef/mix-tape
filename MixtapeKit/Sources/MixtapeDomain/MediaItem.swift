//  MediaItem.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct MediaItem: Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let kind: MediaKind
    let overview: String?
    let productionYear: Int?
    let runtime: Duration?
    /// Episode or track number.
    let indexNumber: Int?
    /// Season number.
    let parentIndexNumber: Int?
    let seriesName: String?
    let albumArtist: String?
    let primaryImageTag: String?
    let backdropImageTag: String?
    /// Album art inherited by tracks (decision 25: a track's own tags are empty).
    let parentPrimaryImageTag: String?
    let playback: PlaybackState
}
