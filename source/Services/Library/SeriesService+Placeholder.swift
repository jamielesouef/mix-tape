//  SeriesService+Placeholder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public extension SeriesService {
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
