//  SearchService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class SearchService {
    private static let debounce: Duration = .milliseconds(250)

    // MARK: - Properties

    private(set) var query = ""
    private(set) var result: LoadState<SearchResult> = .idle
    private(set) var isOffline = false

    private let search: SearchLibraryUseCase
    private let sessionService: SessionService
    private let downloadsService: DownloadsService
    private let networkMonitor: NetworkPathMonitor

    @ObservationIgnored private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        search: SearchLibraryUseCase,
        sessionService: SessionService,
        downloadsService: DownloadsService,
        networkMonitor: NetworkPathMonitor,
        query: String = "",
        result: LoadState<SearchResult> = .idle
    ) {
        self.search = search
        self.sessionService = sessionService
        self.downloadsService = downloadsService
        self.networkMonitor = networkMonitor
        self.query = query
        self.result = result
    }

    // MARK: - Public API

    func updateQuery(_ text: String) {
        query = text
        searchTask?.cancel()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.isEmpty == false else {
            result = .idle
            return
        }
        guard let session = sessionService.currentSession else {
            return
        }

        result = .loading

        searchTask = Task { [weak self] in
            await self?.performSearch(trimmed, session: session)
        }
    }

    func clear() {
        searchTask?.cancel()

        query = ""
        result = .idle
    }

    // MARK: - Private

    private func performSearch(_ query: String, session: UserSession) async {
        try? await Task.sleep(for: Self.debounce)

        guard Task.isCancelled == false else {
            return
        }

        let status = await networkMonitor.status()

        isOffline = status.isConnected == false

        do {
            let searched = try await search(query: query, session: session)
            let filtered = isOffline ? offlineOnly(searched) : searched

            guard Task.isCancelled == false else {
                return
            }

            result = .loaded(filtered)
        } catch {
            guard Task.isCancelled == false else {
                return
            }

            result = .failed(MixtapeError.mapping(from: error))
        }
    }

    private func offlineOnly(_ searchResult: SearchResult) -> SearchResult {
        let downloaded = Set(downloadsService.downloadedAlbumIDs)

        return SearchResult(
            albums: searchResult.albums.filter { downloaded.contains($0.id) },
            tracks: searchResult.tracks.filter { $0.albumID.map(downloaded.contains) ?? false }
        )
    }
}
