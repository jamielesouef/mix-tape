//  MockSeriesService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG

    public enum MockSeriesService {
        public static func make(
            repository: MockLibraryRepository = MockLibraryRepository(),
            sessionService: SessionService = MockSessionService.signedIn(),
            seasons: [String: LoadState<[MediaItem]>] = [:],
            episodes: [String: LoadState<[MediaItem]>] = [:],
        ) -> SeriesService {
            SeriesService(
                fetchSeasons: FetchSeasonsUseCase(repository: repository),
                fetchEpisodes: FetchEpisodesUseCase(repository: repository),
                sessionService: sessionService,
                seasons: seasons,
                episodes: episodes,
            )
        }

        public static func idle() -> SeriesService {
            make()
        }

        public static func loaded() -> SeriesService {
            make(
                seasons: ["series-1": .loaded(MockLibraryRepository.sampleSeasons)],
                episodes: ["season-1": .loaded(MockLibraryRepository.sampleEpisodes), "season-2": .loaded([])],
            )
        }

        public static func empty() -> SeriesService {
            make(seasons: ["series-1": .loaded([])])
        }

        public static func failed(_ error: MixtapeError = .serverUnreachable) -> SeriesService {
            make(
                repository: MockLibraryRepository(seasonsResult: { _, _ in throw error }, episodesResult: { _, _, _ in throw error }),
                seasons: ["series-1": .failed(error)],
            )
        }
    }
#endif
