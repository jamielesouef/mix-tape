//  LibraryPagesService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

import Observation

/// Caches one library's paged item list and drives "load more" as the wallet scrolls.
///
/// Shares `LibraryService`'s `LoadEpochTracker` rather than owning one, so a sign-out or a
/// refresh invalidates an in-flight page load the same way it invalidates every other load.
@MainActor
@Observable
final class LibraryPagesService {
    private(set) var pages: [String: LoadState<Page<MediaItem>>]
    private(set) var pageLoadError: [String: MixtapeError] = [:]

    private var inFlight: Set<String> = []
    private var exhausted: Set<String> = []

    private let epoch: LoadEpochTracker
    private let fetchLibraryItems: FetchLibraryItemsUseCase
    private let pageSize: Int

    init(
        fetchLibraryItems: FetchLibraryItemsUseCase,
        epoch: LoadEpochTracker,
        pageSize: Int,
        pages: [String: LoadState<Page<MediaItem>>] = [:]
    ) {
        self.fetchLibraryItems = fetchLibraryItems
        self.epoch = epoch
        self.pageSize = pageSize
        self.pages = pages
    }

    /// Whether this library's first page is already loaded — the caller should skip loading.
    func isLoaded(_ id: String) -> Bool {
        if case .loaded = pages[id] {
            return true
        }
        return false
    }

    func isInFlight(_ id: String) -> Bool {
        inFlight.contains(id)
    }

    func markFailed(id: String, error: MixtapeError) {
        pages[id] = .failed(error)
    }

    func loadFirstPage(
        id: String,
        kind: MediaKind,
        epoch requestEpoch: UserSession,
        generation: OperationGeneration
    ) async {
        inFlight.insert(id)
        defer { inFlight.remove(id) }

        exhausted.remove(id)
        pages[id] = .loading

        let request = PageRequest(startIndex: 0, limit: pageSize)

        guard
            let result = await epoch.fetchCurrent(epoch: requestEpoch, generation: generation, {
                try await fetchLibraryItems(
                    libraryID: id,
                    kind: kind,
                    page: request,
                    session: requestEpoch
                )
            })
        else {
            return
        }

        switch result {
        case let .success(page):
            pages[id] = .loaded(page)

            if page.items.count < pageSize || page.items.count >= page.totalCount {
                exhausted.insert(id)
            }
        case let .failure(mapped):
            pages[id] = .failed(mapped)
        }
    }

    func loadMore(
        id: String,
        kind: MediaKind,
        epoch requestEpoch: UserSession,
        generation: OperationGeneration
    ) async {
        guard inFlight.contains(id) == false, exhausted.contains(id) == false else {
            return
        }
        guard case let .loaded(current) = pages[id] else {
            return
        }

        inFlight.insert(id)
        defer { inFlight.remove(id) }

        let request = PageRequest(startIndex: current.items.count, limit: pageSize)

        guard
            let result = await epoch.fetchCurrent(epoch: requestEpoch, generation: generation, {
                try await fetchLibraryItems(
                    libraryID: id,
                    kind: kind,
                    page: request,
                    session: requestEpoch
                )
            })
        else {
            return
        }

        switch result {
        case let .success(next):
            let merged = current.items + next.items

            pages[id] = .loaded(Page(
                items: merged,
                totalCount: next.totalCount,
                startIndex: current.startIndex
            ))
            pageLoadError[id] = nil

            if next.items.count < pageSize || merged.count >= next.totalCount {
                exhausted.insert(id)
            }
        case let .failure(mapped):
            pageLoadError[id] = mapped
        }
    }

    func reset() {
        pages = [:]
        pageLoadError = [:]
        exhausted = []
    }
}
