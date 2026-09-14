//  LibraryDetailsService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

import Observation

/// Caches one item's full detail per item id.
///
/// Shares `LibraryService`'s `LoadEpochTracker` rather than owning one, so a sign-out or a
/// refresh invalidates an in-flight detail load the same way it invalidates a page load.
@MainActor
@Observable
final class LibraryDetailsService {
    private(set) var details: [String: LoadState<MediaItem>]

    private let epoch: LoadEpochTracker
    private let fetchItemDetail: FetchItemDetailUseCase
    private let sessionService: SessionService

    init(
        fetchItemDetail: FetchItemDetailUseCase,
        sessionService: SessionService,
        epoch: LoadEpochTracker,
        details: [String: LoadState<MediaItem>] = [:]
    ) {
        self.fetchItemDetail = fetchItemDetail
        self.sessionService = sessionService
        self.epoch = epoch
        self.details = details
    }

    func loadDetail(id: String) async {
        guard let session = sessionService.currentSession else {
            return
        }

        let requestEpoch = session
        let generation = epoch.generation

        details[id] = .loading

        guard
            let result = await epoch.fetchCurrent(epoch: requestEpoch, generation: generation, {
                try await fetchItemDetail(id: id, session: requestEpoch)
            })
        else {
            return
        }

        switch result {
        case let .success(loaded): details[id] = .loaded(loaded)
        case let .failure(mapped): details[id] = .failed(mapped)
        }
    }

    func reset() {
        details = [:]
    }
}
