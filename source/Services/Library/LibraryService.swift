//  LibraryService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import Observation

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
        pageLoadError: [String: MixtapeError] = [:],
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
        guard let session else { return }
        let epoch = session
        let generation = currentGeneration
        libraries = .loading
        do {
            let loaded = try await fetchLibraries(session: session)
            if self.session == epoch, currentGeneration == generation {
                libraries = .loaded(loaded)
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch, currentGeneration == generation {
                libraries = .failed(mapped)
            }
        }
    }

    func loadLibrary(id: String) async {
        guard let session else { return }
        let epoch = session
        let generation = currentGeneration
        if case .loaded = pages[id] {
            return
        }
        guard inFlight.contains(id) == false else { return }
        if libraries.isLoaded == false {
            do {
                let loaded = try await fetchLibraries(session: session)
                if self.session == epoch, currentGeneration == generation {
                    libraries = .loaded(loaded)
                }
            } catch {
                let mapped = handle(error)
                if self.session == epoch, currentGeneration == generation {
                    libraries = .failed(mapped)
                }
            }
        }
        guard let library = library(id: id) else {
            if self.session == epoch, currentGeneration == generation {
                pages[id] = .failed(.transport("Library not found"))
            }
            return
        }
        inFlight.insert(id)
        defer { inFlight.remove(id) }
        exhausted.remove(id)
        pages[id] = .loading
        do {
            let page = try await fetchLibraryItems(libraryID: id, kind: Self.itemKind(library.kind), page: PageRequest(startIndex: 0, limit: Self.pageSize), session: session)
            if self.session == epoch, currentGeneration == generation {
                pages[id] = .loaded(page)
                if page.items.count < Self.pageSize || page.items.count >= page.totalCount {
                    exhausted.insert(id)
                }
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch, currentGeneration == generation {
                pages[id] = .failed(mapped)
            }
        }
    }

    func loadMore(libraryID id: String) async {
        guard let session, let library = library(id: id) else { return }
        let epoch = session
        let generation = currentGeneration
        guard inFlight.contains(id) == false, exhausted.contains(id) == false else { return }
        guard case let .loaded(current) = pages[id] else { return }
        inFlight.insert(id)
        defer { inFlight.remove(id) }
        do {
            let request = PageRequest(startIndex: current.items.count, limit: Self.pageSize)
            let next = try await fetchLibraryItems(libraryID: id, kind: Self.itemKind(library.kind), page: request, session: session)
            if self.session == epoch, currentGeneration == generation {
                let merged = current.items + next.items
                pages[id] = .loaded(Page(items: merged, totalCount: next.totalCount, startIndex: current.startIndex))
                pageLoadError[id] = nil
                if next.items.count < Self.pageSize || merged.count >= next.totalCount {
                    exhausted.insert(id)
                }
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch, currentGeneration == generation {
                pageLoadError[id] = mapped
            }
        }
    }

    func loadDetail(id: String) async {
        guard let session else { return }
        let epoch = session
        let generation = currentGeneration
        details[id] = .loading
        do {
            let loaded = try await fetchItemDetail(id: id, session: session)
            if self.session == epoch, currentGeneration == generation {
                details[id] = .loaded(loaded)
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch, currentGeneration == generation {
                details[id] = .failed(mapped)
            }
        }
    }

    func loadTracks(albumID: String) async {
        guard let session else { return }
        let epoch = session
        let generation = currentGeneration
        if case .loaded = tracks[albumID] {
            return
        }
        guard tracksInFlight.contains(albumID) == false else { return }
        tracksInFlight.insert(albumID)
        defer { tracksInFlight.remove(albumID) }
        tracks[albumID] = .loading
        do {
            let loaded = try await fetchAlbumTracks(albumID: albumID, session: session)
            if self.session == epoch, currentGeneration == generation {
                tracks[albumID] = .loaded(loaded)
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch, currentGeneration == generation {
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

    private func handle(_ error: any Error) -> MixtapeError {
        let mapped = (error as? MixtapeError) ?? .transport(error.localizedDescription)
        if mapped == .sessionExpired {
            sessionService.handleSessionExpiry()
        }
        return mapped
    }
}
