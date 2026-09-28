//  SearchResult.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

struct SearchResult: Sendable, Equatable {
    let albums: [MediaItem]
    let tracks: [MediaItem]

    static let empty = SearchResult(albums: [], tracks: [])

    var isEmpty: Bool {
        albums.isEmpty && tracks.isEmpty
    }
}
