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
    static let pageSize = 60

    // MARK: - Properties

    private(set) var libraries: LoadState<[Library]> = .idle
    private(set) var details: [String: LoadState<MediaItem>] = [:]

    private let epoch: LoadEpochTracker
    private let pagesService: LibraryPagesService
    private let albumTracksService: AlbumTracksService
    private let fetchLibraries: FetchLibrariesUseCase
    private let fetchItemDetail: FetchItemDetailUseCase
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
        self.fetchItemDetail = fetchItemDetail
        self.sessionService = sessionService
        epoch = LoadEpochTracker(sessionService: sessionService)
        pagesService = LibraryPagesService(
            fetchLibraryItems: fetchLibraryItems,
            epoch: epoch,
            pageSize: Self.pageSize,
            pages: pages
        )
        albumTracksService = AlbumTracksService(
            fetchAlbumTracks: fetchAlbumTracks,
            sessionService: sessionService,
            epoch: epoch,
            tracks: tracks
        )
        self.libraries = libraries
        self.details = details
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

        guard let library = library(id: id) else {
            if epoch.isCurrent(epoch: requestEpoch, generation: generation) {
                pagesService.markFailed(id: id, error: .transport("Library not found"))
            }
            return
        }

        await pagesService.loadFirstPage(
            id: id,
            kind: Self.itemKind(library.kind),
            epoch: requestEpoch,
            generation: generation
        )
    }

    func loadMore(libraryID id: String) async {
        guard let session, let library = library(id: id) else {
            return
        }

        await pagesService.loadMore(
            id: id,
            kind: Self.itemKind(library.kind),
            epoch: session,
            generation: epoch.generation
        )
    }

    func loadDetail(id: String) async {
        guard let session else {
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

    func loadTracks(albumID: String) async {
        await albumTracksService.loadTracks(albumID: albumID)
    }

    func refresh() async {
        epoch.advance()

        details = [:]
        pagesService.reset()
        albumTracksService.reset()

        await loadHome()
    }

    func endSession() {
        libraries = .idle
        details = [:]
        pagesService.reset()
        albumTracksService.reset()
    }

    // MARK: - Private

    private var session: UserSession? {
        sessionService.currentSession
    }

    static func itemKind(_: LibraryKind) -> MediaKind {
        .musicAlbum
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
