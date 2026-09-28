//  MockSearchService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

#if DEBUG

    @MainActor
    enum MockSearchService {
        static func make(
            repository: MockServerSearchRepository = MockServerSearchRepository(),
            sessionService: SessionService = MockSessionService.signedIn(),
            downloadsService: DownloadsService = MockDownloadsService.idle(),
            query: String = "",
            result: LoadState<SearchResult> = .idle
        ) -> SearchService {
            SearchService(
                search: SearchLibraryUseCase(repository: repository),
                sessionService: sessionService,
                downloadsService: downloadsService,
                networkMonitor: NetworkPathMonitor(),
                query: query,
                result: result
            )
        }

        static func idle() -> SearchService {
            make()
        }

        static func loaded() -> SearchService {
            make(
                query: "Sleep",
                result: .loaded(SearchResult(albums: [MockMedia.albums[0]], tracks: [MockMedia.tracks[0]]))
            )
        }

        static func empty() -> SearchService {
            make(query: "zzz", result: .loaded(.empty))
        }

        static func failed() -> SearchService {
            make(query: "Sleep", result: .failed(.serverUnreachable))
        }
    }
#endif
