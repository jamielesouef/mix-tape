//  MediaItem+DisplayTitle.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

extension MediaItem {
    nonisolated var displayTitle: String {
        switch kind {
        case .audio:
            guard let track = indexNumber else { return name }
            return "\(track). \(name)"
        case .musicAlbum:
            return name
        }
    }
}
