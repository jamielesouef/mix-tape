//  SeriesService+Placeholder.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeUseCase

public extension SeriesService {
    /// `@Entry` default. Never used by a running app — the composition root always injects one.
    /// Debug builds use the preview mock; release builds, which carry no `Mock*` type (slice 013),
    /// build the same service over the inert `Placeholder*` collaborators.
    static let placeholder: SeriesService = {
        #if DEBUG
            return MockSeriesService.idle()
        #else
            let repository = PlaceholderLibraryRepository()
            return SeriesService(
                fetchSeasons: FetchSeasonsUseCase(repository: repository),
                fetchEpisodes: FetchEpisodesUseCase(repository: repository),
                sessionService: .placeholder,
            )
        #endif
    }()
}
