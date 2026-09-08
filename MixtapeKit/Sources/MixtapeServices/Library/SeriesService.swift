//  SeriesService.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeUseCase
import Observation

/// Engineering doc §6, decision 30: `episodes` takes both ids. Per-series and per-season caches,
/// cleared on `refresh()`.
@Observable
public final class SeriesService {
    public private(set) var seasons: [String: LoadState<[MediaItem]>] = [:]
    public private(set) var episodes: [String: LoadState<[MediaItem]>] = [:]

    private var seasonsInFlight: Set<String> = []
    private var episodesInFlight: Set<String> = []
    /// Bumped by `refresh()`; every in-flight load's post-await write checks it, supplementing
    /// 020's session-identity guard (023 §6 — same rationale as `LibraryService.currentGeneration`).
    private var currentGeneration = OperationGeneration()

    private let fetchSeasons: FetchSeasonsUseCase
    private let fetchEpisodes: FetchEpisodesUseCase
    private let sessionService: SessionService

    public init(
        fetchSeasons: FetchSeasonsUseCase,
        fetchEpisodes: FetchEpisodesUseCase,
        sessionService: SessionService,
        seasons: [String: LoadState<[MediaItem]>] = [:],
        episodes: [String: LoadState<[MediaItem]>] = [:],
    ) {
        self.fetchSeasons = fetchSeasons
        self.fetchEpisodes = fetchEpisodes
        self.sessionService = sessionService
        self.seasons = seasons
        self.episodes = episodes
    }

    /// Coalesced via `seasonsInFlight`, keyed by seriesID — two views asking for the same series'
    /// seasons within the same load fire one network request (023 §6).
    public func loadSeasons(seriesID: String) async {
        guard let session else { return }
        let epoch = session
        let generation = currentGeneration
        if case .loaded = seasons[seriesID] {
            return
        }
        guard seasonsInFlight.contains(seriesID) == false else { return }
        seasonsInFlight.insert(seriesID)
        defer { seasonsInFlight.remove(seriesID) }
        seasons[seriesID] = .loading
        do {
            let loaded = try await fetchSeasons(seriesID: seriesID, session: session)
            if self.session == epoch, currentGeneration == generation {
                seasons[seriesID] = .loaded(loaded)
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch, currentGeneration == generation {
                seasons[seriesID] = .failed(mapped)
            }
        }
    }

    /// Coalesced via `episodesInFlight`, keyed by seasonID — two views asking for the same
    /// season's episodes within the same load fire one network request (023 §6).
    public func loadEpisodes(seriesID: String, seasonID: String) async {
        guard let session else { return }
        let epoch = session
        let generation = currentGeneration
        if case .loaded = episodes[seasonID] {
            return
        }
        guard episodesInFlight.contains(seasonID) == false else { return }
        episodesInFlight.insert(seasonID)
        defer { episodesInFlight.remove(seasonID) }
        episodes[seasonID] = .loading
        do {
            let loaded = try await fetchEpisodes(seriesID: seriesID, seasonID: seasonID, session: session)
            if self.session == epoch, currentGeneration == generation {
                episodes[seasonID] = .loaded(loaded)
            }
        } catch {
            let mapped = handle(error)
            if self.session == epoch, currentGeneration == generation {
                episodes[seasonID] = .failed(mapped)
            }
        }
    }

    /// Bumps the generation first so any load already in flight sees a stale generation on its
    /// post-await write and skips it (023 §6, additive to 020's session-identity guard).
    public func refresh() {
        currentGeneration = OperationGeneration()
        seasons = [:]
        episodes = [:]
    }

    /// Slice 020: `SessionService`'s fan-out calls this when a session ends — sign-out or expiry.
    /// Every cache returns to empty, never `.failed` — same rationale as `LibraryService.endSession()`.
    public func endSession() {
        seasons = [:]
        episodes = [:]
    }

    private var session: UserSession? {
        if case let .signedIn(session) = sessionService.state {
            return session
        }
        return nil
    }

    private func handle(_ error: any Error) -> MixtapeError {
        let mapped = (error as? MixtapeError) ?? .transport(error.localizedDescription)
        if mapped == .sessionExpired {
            sessionService.handleSessionExpiry()
        }
        return mapped
    }
}
