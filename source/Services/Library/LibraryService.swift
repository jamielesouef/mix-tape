//  LibraryService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class LibraryService {
    // MARK: - Properties

    private(set) var libraries: LoadState<[Library]> = .idle

    private let epoch: LoadEpochTracker
    private let pagesService: LibraryPagesService
    private let albumTracksService: AlbumTracksService
    private let detailsService: LibraryDetailsService
    private let fetchLibraries: FetchLibrariesUseCase
    private let sessionService: SessionService

    // MARK: - Initialization

    init(
        fetchLibraries: FetchLibrariesUseCase,
        fetchLibraryItems: FetchLibraryItemsUseCase,
        fetchItemDetail: FetchItemDetailUseCase,
        fetchAlbumTracks: FetchAlbumTracksUseCase,
        sessionService: SessionService,
        libraries: LoadState<[Library]> = .idle,
        pages: [String: LoadState<Page<MediaItem>>] = [:],
        details: [String: LoadState<MediaItem>] = [:],
        tracks: [String: LoadState<[MediaItem]>] = [:],
        pageLoadError: [String: MixtapeError] = [:]
    ) {
        self.fetchLibraries = fetchLibraries
        self.sessionService = sessionService
        epoch = LoadEpochTracker(sessionService: sessionService)
        pagesService = LibraryPagesService(
            fetchLibraryItems: fetchLibraryItems,
            epoch: epoch,
            pages: pages
        )
        albumTracksService = AlbumTracksService(
            fetchAlbumTracks: fetchAlbumTracks,
            sessionService: sessionService,
            epoch: epoch,
            tracks: tracks
        )
        detailsService = LibraryDetailsService(
            fetchItemDetail: fetchItemDetail,
            sessionService: sessionService,
            epoch: epoch,
            details: details
        )
        self.libraries = libraries
    }

    // MARK: - Public API

    var loadedLibraries: [Library] {
        if case let .loaded(list) = libraries {
            return list
        }
        return []
    }

    func library(id: String) -> Library? {
        loadedLibraries.first { $0.id == id }
    }

    var pages: [String: LoadState<Page<MediaItem>>] {
        pagesService.pages
    }

    var pageLoadError: [String: MixtapeError] {
        pagesService.pageLoadError
    }

    var tracks: [String: LoadState<[MediaItem]>] {
        albumTracksService.tracks
    }

    var details: [String: LoadState<MediaItem>] {
        detailsService.details
    }

    func loadHome() async {
        guard let session else {
            return
        }

        let generation = epoch.generation

        libraries = .loading

        await loadLibraries(epoch: session, generation: generation)
    }

    func loadLibrary(id: String) async {
        guard let session else {
            return
        }
        guard pagesService.isLoaded(id) == false, pagesService.isInFlight(id) == false else {
            return
        }

        let requestEpoch = session
        let generation = epoch.generation

        if libraries.isLoaded == false {
            await loadLibraries(epoch: requestEpoch, generation: generation)
        }

        guard library(id: id) != nil else {
            if epoch.isCurrent(epoch: requestEpoch, generation: generation) {
                pagesService.markFailed(id: id, error: .transport("Library not found"))
            }
            return
        }

        await pagesService.loadFirstPage(
            id: id,
            kind: .musicAlbum,
            epoch: requestEpoch,
            generation: generation
        )
    }

    func loadMore(libraryID id: String) async {
        guard let session, library(id: id) != nil else {
            return
        }

        await pagesService.loadMore(
            id: id,
            kind: .musicAlbum,
            epoch: session,
            generation: epoch.generation
        )
    }

    func loadDetail(id: String) async {
        await detailsService.loadDetail(id: id)
    }

    func loadTracks(albumID: String) async {
        await albumTracksService.loadTracks(albumID: albumID)
    }

    func refresh() async {
        epoch.advance()

        detailsService.reset()
        pagesService.reset()
        albumTracksService.reset()

        await loadHome()
    }

    func endSession() {
        libraries = .idle
        detailsService.reset()
        pagesService.reset()
        albumTracksService.reset()
    }

    // MARK: - Private

    private var session: UserSession? {
        sessionService.currentSession
    }

    /// Fetches the library list into `libraries`. Shared by the home load and by the album
    /// load, which needs the list on hand before it can resolve a library by id.
    private func loadLibraries(
        epoch requestEpoch: UserSession,
        generation: OperationGeneration
    ) async {
        guard
            let result = await epoch.fetchCurrent(epoch: requestEpoch, generation: generation, {
                try await fetchLibraries(session: requestEpoch)
            })
        else {
            return
        }

        switch result {
        case let .success(loaded): libraries = .loaded(loaded)
        case let .failure(mapped): libraries = .failed(mapped)
        }
    }
}
