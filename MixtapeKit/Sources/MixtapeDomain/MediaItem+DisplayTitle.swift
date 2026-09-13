//  MediaItem+DisplayTitle.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public extension MediaItem {
    nonisolated var displayTitle: String {
        switch kind {
        case .episode:
            guard let season = parentIndexNumber, let episode = indexNumber else { return name }
            return "S\(season)E\(episode) · \(name)"
        case .audio:
            guard let track = indexNumber else { return name }
            return "\(track). \(name)"
        case .movie, .series, .season, .musicAlbum:
            return name
        }
    }
}
