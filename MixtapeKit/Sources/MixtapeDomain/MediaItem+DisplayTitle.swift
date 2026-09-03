//  MediaItem+DisplayTitle.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public extension MediaItem {
    /// Episodes render as `S2E4 · Title`, tracks as `3. Title`, everything else as the name.
    /// A missing index number falls back to the bare name.
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
