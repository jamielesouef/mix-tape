//  MockLibraryService.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG
    import MixtapeDomain
    import MixtapeUseCase

    public enum MockLibraryService {
        public static func make(
            repository: MockLibraryRepository = MockLibraryRepository(),
            sessionService: SessionService = MockSessionService.signedIn(),
            libraries: LoadState<[Library]> = .idle,
            continueWatching: LoadState<[MediaItem]> = .idle,
            pages: [String: LoadState<Page<MediaItem>>] = [:],
            details: [String: LoadState<MediaItem>] = [:],
            tracks: [String: LoadState<[MediaItem]>] = [:],
        ) -> LibraryService {
            LibraryService(
                fetchLibraries: FetchLibrariesUseCase(repository: repository),
                fetchLibraryItems: FetchLibraryItemsUseCase(repository: repository),
                fetchItemDetail: FetchItemDetailUseCase(repository: repository),
                fetchAlbumTracks: FetchAlbumTracksUseCase(repository: repository),
                fetchContinueWatching: FetchContinueWatchingUseCase(repository: repository),
                sessionService: sessionService,
                libraries: libraries,
                continueWatching: continueWatching,
                pages: pages,
                details: details,
                tracks: tracks,
            )
        }

        public static func idle() -> LibraryService {
            make()
        }

        public static func loading() -> LibraryService {
            make(libraries: .loading, continueWatching: .loading, pages: ["lib-movies": .loading, "lib-shows": .loading, "lib-music": .loading])
        }

        public static func loaded() -> LibraryService {
            let libraries = MockLibraryRepository.sampleLibraries.filter { $0.kind != .unsupported }
            return make(
                libraries: .loaded(libraries),
                continueWatching: .loaded(MockLibraryRepository.sampleContinueWatching),
                pages: [
                    "lib-movies": .loaded(page(MockLibraryRepository.sampleMovies)),
                    "lib-shows": .loaded(page([MockLibraryRepository.sampleSeries])),
                    "lib-music": .loaded(page(MockLibraryRepository.sampleAlbums)),
                ],
                details: ["movie-2": .loaded(MockLibraryRepository.sampleMovies[1])],
                tracks: ["album-1": .loaded(MockLibraryRepository.sampleTracks)],
            )
        }

        public static func empty() -> LibraryService {
            make(
                libraries: .loaded([]),
                continueWatching: .loaded([]),
                pages: ["lib-movies": .loaded(page([])), "lib-shows": .loaded(page([])), "lib-music": .loaded(page([]))],
                tracks: ["album-1": .loaded([])],
            )
        }

        public static func failed(_ error: MixtapeError = .serverUnreachable) -> LibraryService {
            make(
                repository: MockLibraryRepository(
                    librariesResult: { _ in throw error },
                    itemsResult: { _, _, _, _ in throw error },
                    itemResult: { _, _ in throw error },
                    tracksResult: { _, _ in throw error },
                    continueWatchingResult: { _ in throw error },
                ),
                libraries: .failed(error),
                continueWatching: .failed(error),
                pages: ["lib-movies": .failed(error), "lib-shows": .failed(error), "lib-music": .failed(error)],
                details: ["movie-2": .failed(error)],
                tracks: ["album-1": .failed(error)],
            )
        }

        private static func page(_ items: [MediaItem]) -> Page<MediaItem> {
            Page(items: items, totalCount: items.count, startIndex: 0)
        }
    }
#endif
