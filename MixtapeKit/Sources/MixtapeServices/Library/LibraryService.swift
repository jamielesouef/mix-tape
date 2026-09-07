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
        let epoch = session
        libraries = .loading
        continueWatching = .loading
        do {
            let loaded = try await fetchLibraries(session: session)
            if self.session == epoch {
                libraries = .loaded(loaded)
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch {
                libraries = .failed(mapped)
            }
        }
        do {
            let loaded = try await fetchContinueWatching(session: session)
            if self.session == epoch {
                continueWatching = .loaded(loaded)
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch {
                continueWatching = .failed(mapped)
            }
        }
    }

    /// First page of a library. A library already loaded is left alone — that is the cache.
    public func loadLibrary(id: String) async {
        guard let session else { return }
        let epoch = session
        if case .loaded = pages[id] {
            return
        }
        guard inFlight.contains(id) == false else { return }
        if libraries.isLoaded == false {
            do {
                let loaded = try await fetchLibraries(session: session)
                if self.session == epoch {
                    libraries = .loaded(loaded)
                }
            } catch {
                let mapped = handle(error)
                if self.session == epoch {
                    libraries = .failed(mapped)
                }
            }
        }
        guard let library = library(id: id) else {
            if self.session == epoch {
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
            // Re-checked after the await: 020's session-identity guard closes the reentrancy hazard
            // where handle(error) below fires SessionService's endSession() fan-out mid-flight and
            // this write would otherwise repopulate the cache that fan-out just cleared.
            if self.session == epoch {
                pages[id] = .loaded(page)
                if page.items.count < Self.pageSize || page.items.count >= page.totalCount {
                    exhausted.insert(id)
                }
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch {
                pages[id] = .failed(mapped)
            }
        }
    }

    /// Next page, appended. No-op while in flight, after a short page, or before the first page.
    public func loadMore(libraryID id: String) async {
        guard let session, let library = library(id: id) else { return }
        let epoch = session
        guard inFlight.contains(id) == false, exhausted.contains(id) == false else { return }
        guard case let .loaded(current) = pages[id] else { return }
        inFlight.insert(id)
        defer { inFlight.remove(id) }
        do {
            let request = PageRequest(startIndex: current.items.count, limit: Self.pageSize)
            let next = try await fetchLibraryItems(libraryID: id, kind: Self.itemKind(library.kind), page: request, session: session)
            if self.session == epoch {
                let merged = current.items + next.items
                pages[id] = .loaded(Page(items: merged, totalCount: next.totalCount, startIndex: current.startIndex))
                if next.items.count < Self.pageSize || merged.count >= next.totalCount {
                    exhausted.insert(id)
                }
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch {
                pages[id] = .failed(mapped)
            }
        }
    }

    public func loadDetail(id: String) async {
        guard let session else { return }
        let epoch = session
        details[id] = .loading
        do {
            let loaded = try await fetchItemDetail(id: id, session: session)
            if self.session == epoch {
                details[id] = .loaded(loaded)
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch {
                details[id] = .failed(mapped)
            }
        }
    }

    public func loadTracks(albumID: String) async {
        guard let session else { return }
        let epoch = session
        if case .loaded = tracks[albumID] {
            return
        }
        tracks[albumID] = .loading
        do {
            let loaded = try await fetchAlbumTracks(albumID: albumID, session: session)
            if self.session == epoch {
                tracks[albumID] = .loaded(loaded)
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch {
                tracks[albumID] = .failed(mapped)
            }
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

    /// Slice 020: `SessionService`'s fan-out calls this when a session ends — sign-out or expiry.
    /// Every cache returns to its starting `.idle`/empty value, never `.failed` (decision log): the
    /// next screen's `.task` gate is `if case .idle`, so a `.failed` write would strand it on a
    /// manual-retry view instead of refetching silently for the next session.
    public func endSession() {
        libraries = .idle
        continueWatching = .idle
        pages = [:]
        details = [:]
        tracks = [:]
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
