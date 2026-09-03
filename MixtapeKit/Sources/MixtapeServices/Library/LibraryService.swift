//  LibraryService.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeUseCase
import Observation

/// Engineering doc §6. Holds the libraries, Continue Watching and a per-library page cache so tab
/// switches do not refetch. Paging: `limit = 60`, `startIndex` advanced by the returned count;
/// `loadMore` is a no-op while a load is in flight or after a short page.
@Observable
public final class LibraryService {
    public static let pageSize = 60

    public private(set) var libraries: LoadState<[Library]> = .idle
    public private(set) var continueWatching: LoadState<[MediaItem]> = .idle
    public private(set) var pages: [String: LoadState<Page<MediaItem>>] = [:]
    public private(set) var details: [String: LoadState<MediaItem>] = [:]
    public private(set) var tracks: [String: LoadState<[MediaItem]>] = [:]

    private var inFlight: Set<String> = []
    private var exhausted: Set<String> = []

    private let fetchLibraries: FetchLibrariesUseCase
    private let fetchLibraryItems: FetchLibraryItemsUseCase
    private let fetchItemDetail: FetchItemDetailUseCase
    private let fetchAlbumTracks: FetchAlbumTracksUseCase
    private let fetchContinueWatching: FetchContinueWatchingUseCase
    private let sessionService: SessionService

    public init(
        fetchLibraries: FetchLibrariesUseCase,
        fetchLibraryItems: FetchLibraryItemsUseCase,
        fetchItemDetail: FetchItemDetailUseCase,
        fetchAlbumTracks: FetchAlbumTracksUseCase,
        fetchContinueWatching: FetchContinueWatchingUseCase,
        sessionService: SessionService,
        libraries: LoadState<[Library]> = .idle,
        continueWatching: LoadState<[MediaItem]> = .idle,
        pages: [String: LoadState<Page<MediaItem>>] = [:],
        details: [String: LoadState<MediaItem>] = [:],
        tracks: [String: LoadState<[MediaItem]>] = [:],
    ) {
        self.fetchLibraries = fetchLibraries
        self.fetchLibraryItems = fetchLibraryItems
        self.fetchItemDetail = fetchItemDetail
        self.fetchAlbumTracks = fetchAlbumTracks
        self.fetchContinueWatching = fetchContinueWatching
        self.sessionService = sessionService
        self.libraries = libraries
        self.continueWatching = continueWatching
        self.pages = pages
        self.details = details
        self.tracks = tracks
    }

    public var loadedLibraries: [Library] {
        if case let .loaded(list) = libraries {
            return list
        }
        return []
    }

    public func library(id: String) -> Library? {
        loadedLibraries.first { $0.id == id }
    }

    /// Libraries and Continue Watching (decision 13: no Recently Added).
    public func loadHome() async {
        guard let session else { return }
        libraries = .loading
        continueWatching = .loading
        do {
            libraries = try await .loaded(fetchLibraries(session: session))
        } catch {
            libraries = .failed(handle(error))
        }
        do {
            continueWatching = try await .loaded(fetchContinueWatching(session: session))
        } catch {
            continueWatching = .failed(handle(error))
        }
    }

    /// First page of a library. A library already loaded is left alone — that is the cache.
    public func loadLibrary(id: String) async {
        guard let session else { return }
        if case .loaded = pages[id] {
            return
        }
        guard inFlight.contains(id) == false else { return }
        if libraries.isLoaded == false {
            do {
                libraries = try await .loaded(fetchLibraries(session: session))
            } catch {
                libraries = .failed(handle(error))
            }
        }
        guard let library = library(id: id) else {
            pages[id] = .failed(.transport("Library not found"))
            return
        }
        inFlight.insert(id)
        defer { inFlight.remove(id) }
        exhausted.remove(id)
        pages[id] = .loading
        do {
            let page = try await fetchLibraryItems(libraryID: id, kind: Self.itemKind(library.kind), page: PageRequest(startIndex: 0, limit: Self.pageSize), session: session)
            pages[id] = .loaded(page)
            if page.items.count < Self.pageSize || page.items.count >= page.totalCount {
                exhausted.insert(id)
            }
        } catch {
            pages[id] = .failed(handle(error))
        }
    }

    /// Next page, appended. No-op while in flight, after a short page, or before the first page.
    public func loadMore(libraryID id: String) async {
        guard let session, let library = library(id: id) else { return }
        guard inFlight.contains(id) == false, exhausted.contains(id) == false else { return }
        guard case let .loaded(current) = pages[id] else { return }
        inFlight.insert(id)
        defer { inFlight.remove(id) }
        do {
            let request = PageRequest(startIndex: current.items.count, limit: Self.pageSize)
            let next = try await fetchLibraryItems(libraryID: id, kind: Self.itemKind(library.kind), page: request, session: session)
            let merged = current.items + next.items
            pages[id] = .loaded(Page(items: merged, totalCount: next.totalCount, startIndex: current.startIndex))
            if next.items.count < Self.pageSize || merged.count >= next.totalCount {
                exhausted.insert(id)
            }
        } catch {
            pages[id] = .failed(handle(error))
        }
    }

    public func loadDetail(id: String) async {
        guard let session else { return }
        details[id] = .loading
        do {
            details[id] = try await .loaded(fetchItemDetail(id: id, session: session))
        } catch {
            details[id] = .failed(handle(error))
        }
    }

    public func loadTracks(albumID: String) async {
        guard let session else { return }
        if case .loaded = tracks[albumID] {
            return
        }
        tracks[albumID] = .loading
        do {
            tracks[albumID] = try await .loaded(fetchAlbumTracks(albumID: albumID, session: session))
        } catch {
            tracks[albumID] = .failed(handle(error))
        }
    }

    /// Drops every cache and reloads Home. Library pages reload on their next appearance.
    public func refresh() async {
        pages = [:]
        details = [:]
        tracks = [:]
        exhausted = []
        await loadHome()
    }

    private var session: UserSession? {
        if case let .signedIn(session) = sessionService.state {
            return session
        }
        return nil
    }

    static func itemKind(_ kind: LibraryKind) -> MediaKind {
        switch kind {
        case .movies: .movie
        case .tvShows: .series
        case .music, .unsupported: .musicAlbum
        }
    }

    /// Maps and, for `.sessionExpired`, hands the session back to `SessionService` (§6).
    private func handle(_ error: any Error) -> MixtapeError {
        let mapped = (error as? MixtapeError) ?? .transport(error.localizedDescription)
        if mapped == .sessionExpired {
            sessionService.handleSessionExpiry()
        }
        return mapped
    }
}
