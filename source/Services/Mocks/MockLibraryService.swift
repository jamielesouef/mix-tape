//  MockLibraryService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG

    enum MockLibraryService {
        static func make(
            repository: MockLibraryRepository = MockLibraryRepository(),
            sessionService: SessionService = MockSessionService.signedIn(),
            libraries: LoadState<[Library]> = .idle,
            pages: [String: LoadState<Page<MediaItem>>] = [:],
            details: [String: LoadState<MediaItem>] = [:],
            tracks: [String: LoadState<[MediaItem]>] = [:],
        ) -> LibraryService {
            LibraryService(
                fetchLibraries: FetchLibrariesUseCase(repository: repository),
                fetchLibraryItems: FetchLibraryItemsUseCase(repository: repository),
                fetchItemDetail: FetchItemDetailUseCase(repository: repository),
                fetchAlbumTracks: FetchAlbumTracksUseCase(repository: repository),
                sessionService: sessionService,
                libraries: libraries,
                pages: pages,
                details: details,
                tracks: tracks,
            )
        }

        static func idle() -> LibraryService {
            make()
        }

        static func loading() -> LibraryService {
            make(libraries: .loading, pages: ["lib-music": .loading])
        }

        static func loaded() -> LibraryService {
            let libraries = MockLibraryRepository.sampleLibraries.filter { $0.kind != .unsupported }
            return make(
                libraries: .loaded(libraries),
                pages: [
                    "lib-music": .loaded(page(MockLibraryRepository.sampleAlbums)),
                ],
                details: ["album-1": .loaded(MockLibraryRepository.sampleAlbums[0])],
                tracks: ["album-1": .loaded(MockLibraryRepository.sampleTracks)],
            )
        }

        static func empty() -> LibraryService {
            make(
                libraries: .loaded([]),
                pages: ["lib-music": .loaded(page([]))],
                tracks: ["album-1": .loaded([])],
            )
        }

        static func failed(_ error: MixtapeError = .serverUnreachable) -> LibraryService {
            make(
                repository: MockLibraryRepository(
                    librariesResult: { _ in throw error },
                    itemsResult: { _, _, _, _ in throw error },
                    itemResult: { _, _ in throw error },
                    tracksResult: { _, _ in throw error },
                ),
                libraries: .failed(error),
                pages: ["lib-music": .failed(error)],
                details: ["album-1": .failed(error)],
                tracks: ["album-1": .failed(error)],
            )
        }

        private static func page(_ items: [MediaItem]) -> Page<MediaItem> {
            Page(items: items, totalCount: items.count, startIndex: 0)
        }
    }
#endif
