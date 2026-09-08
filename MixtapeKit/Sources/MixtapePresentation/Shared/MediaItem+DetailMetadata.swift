//  MediaItem+DetailMetadata.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import MixtapeDomain

extension MediaItem {
    /// The detail screens' one-line metadata: series, year, runtime, watched — joined with " · ".
    nonisolated var detailMetadata: String {
        var parts: [String] = []
        if let seriesName {
            parts.append(seriesName)
        }
        if let productionYear {
            parts.append(String(productionYear))
        }
        if let runtime {
            parts.append(runtime.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
        }
        if playback.isWatched {
            parts.append("Watched")
        }
        return parts.joined(separator: " · ")
    }
}
