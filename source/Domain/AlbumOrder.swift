//  AlbumOrder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

enum AlbumOrder: String, Sendable, Hashable, CaseIterable, Codable {
    case random
    case title
    case artist
}
