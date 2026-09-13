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

    private(set) var libraries: LoadState<[Library]> = .idle
    private(set) var pages: [String: LoadState<Page<MediaItem>>] = [:]
    private(set) var details: [String: LoadState<MediaItem>] = [:]
    private(set) var tracks: [String: LoadState<[MediaItem]>] = [:]
    private(set) var pageLoadError: [String: MixtapeError] = [:]

    private var inFlight: Set<String> = []
    private var exhausted: Set<String> = []
    private var tracksInFlight: Set<String> = []
    private var currentGeneration = OperationGeneration()

    private let fetchLibraries: FetchLibrariesUseCase
    private let fetchLibraryItems: FetchLibraryItemsUseCase
    private let fetchItemDetail: FetchItemDetailUseCase
    private let fetchAlbumTracks: FetchAlbumTracksUseCase
    private let sessionService: SessionService

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
        self.fetchLibraryItems = fetchLibraryItems
        self.fetchItemDetail = fetchItemDetail
        self.fetchAlbumTracks = fetchAlbumTracks
        self.sessionService = sessionService
        self.libraries = libraries
        self.pages = pages
        self.details = details
        self.tracks = tracks
        self.pageLoadError = pageLoadError
    }

    var loadedLibraries: [Library] {
        if case let .loaded(list) = libraries {
            return list
        }
        return []
    }

    func library(id: String) -> Library? {
        loadedLibraries.first { $0.id == id }
    }

    func loadHome() async {
        guard let session else {
            return
        }

        let generation = currentGeneration

        libraries = .loading

        await loadLibraries(epoch: session, generation: generation)
    }

    func loadLibrary(id: String) async {
        guard let session else {
            return
        }

        if case .loaded = pages[id] {
            return
        }

        guard inFlight.contains(id) == false else {
            return
        }

        let epoch = session
        let generation = currentGeneration

        if libraries.isLoaded == false {
            await loadLibraries(epoch: epoch, generation: generation)
        }

        guard let library = library(id: id) else {
            if isCurrent(epoch: epoch, generation: generation) {
                pages[id] = .failed(.transport("Library not found"))
            }
            return
        }

        inFlight.insert(id)
        defer { inFlight.remove(id) }

        exhausted.remove(id)
        pages[id] = .loading

        do {
            let page = try await fetchLibraryItems(
                libraryID: id,
                kind: Self.itemKind(library.kind),
                page: PageRequest(startIndex: 0, limit: Self.pageSize),
                session: epoch
            )

            guard isCurrent(epoch: epoch, generation: generation) else {
                return
            }

            pages[id] = .loaded(page)

            if page.items.count < Self.pageSize || page.items.count >= page.totalCount {
                exhausted.insert(id)
            }
        } catch {
            let mapped = handle(error)

            if isCurrent(epoch: epoch, generation: generation) {
                pages[id] = .failed(mapped)
            }
        }
    }

    func loadMore(libraryID id: String) async {
        guard let session, let library = library(id: id) else {
            return
        }
        guard inFlight.contains(id) == false, exhausted.contains(id) == false else {
            return
        }
        guard case let .loaded(current) = pages[id] else {
            return
        }

        let epoch = session
        let generation = currentGeneration

        inFlight.insert(id)
        defer { inFlight.remove(id) }

        do {
            let request = PageRequest(startIndex: current.items.count, limit: Self.pageSize)
            let next = try await fetchLibraryItems(
                libraryID: id,
                kind: Self.itemKind(library.kind),
                page: request,
                session: epoch
            )

            guard isCurrent(epoch: epoch, generation: generation) else {
                return
            }

            let merged = current.items + next.items

            pages[id] = .loaded(Page(
                items: merged,
                totalCount: next.totalCount,
                startIndex: current.startIndex
            ))
            pageLoadError[id] = nil

            if next.items.count < Self.pageSize || merged.count >= next.totalCount {
                exhausted.insert(id)
            }
        } catch {
            let mapped = handle(error)

            if isCurrent(epoch: epoch, generation: generation) {
                pageLoadError[id] = mapped
            }
        }
    }

    func loadDetail(id: String) async {
        guard let session else {
            return
        }

        let epoch = session
        let generation = currentGeneration

        details[id] = .loading

        do {
            let loaded = try await fetchItemDetail(id: id, session: epoch)

            if isCurrent(epoch: epoch, generation: generation) {
                details[id] = .loaded(loaded)
            }
        } catch {
            let mapped = handle(error)

            if isCurrent(epoch: epoch, generation: generation) {
                details[id] = .failed(mapped)
            }
        }
    }

    func loadTracks(albumID: String) async {
        guard let session else {
            return
        }

        if case .loaded = tracks[albumID] {
            return
        }

        guard tracksInFlight.contains(albumID) == false else {
            return
        }

        let epoch = session
        let generation = currentGeneration

        tracksInFlight.insert(albumID)
        defer { tracksInFlight.remove(albumID) }

        tracks[albumID] = .loading

        do {
            let loaded = try await fetchAlbumTracks(albumID: albumID, session: epoch)

            if isCurrent(epoch: epoch, generation: generation) {
                tracks[albumID] = .loaded(loaded)
            }
        } catch {
            let mapped = handle(error)

            if isCurrent(epoch: epoch, generation: generation) {
                tracks[albumID] = .failed(mapped)
            }
        }
    }

    func refresh() async {
        currentGeneration = OperationGeneration()

        pages = [:]
        details = [:]
        tracks = [:]
        pageLoadError = [:]
        exhausted = []

        await loadHome()
    }

    func endSession() {
        libraries = .idle
        pages = [:]
        details = [:]
        tracks = [:]
        pageLoadError = [:]
    }

    private var session: UserSession? {
        if case let .signedIn(session) = sessionService.state {
            return session
        }
        return nil
    }

    static func itemKind(_: LibraryKind) -> MediaKind {
        .musicAlbum
    }

    /// Fetches the library list into `libraries`. Shared by the home load and by the album
    /// load, which needs the list on hand before it can resolve a library by id.
    private func loadLibraries(epoch: UserSession, generation: OperationGeneration) async {
        do {
            let loaded = try await fetchLibraries(session: epoch)

            if isCurrent(epoch: epoch, generation: generation) {
                libraries = .loaded(loaded)
            }
        } catch {
            let mapped = handle(error)

            if isCurrent(epoch: epoch, generation: generation) {
                libraries = .failed(mapped)
            }
        }
    }

    /// Whether a result that started under `epoch` and `generation` may still be applied.
    /// A sign-out or a refresh while the request was in flight makes it stale, and stale
    /// results are dropped rather than written over newer state.
    private func isCurrent(epoch: UserSession, generation: OperationGeneration) -> Bool {
        session == epoch && currentGeneration == generation
    }

    private func handle(_ error: any Error) -> MixtapeError {
        let mapped = (error as? MixtapeError) ?? .transport(error.localizedDescription)

        if mapped == .sessionExpired {
            sessionService.handleSessionExpiry()
        }

        return mapped
    }
}
