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

    public func loadSeasons(seriesID: String) async {
        guard let session else { return }
        if case .loaded = seasons[seriesID] {
            return
        }
        seasons[seriesID] = .loading
        do {
            seasons[seriesID] = try await .loaded(fetchSeasons(seriesID: seriesID, session: session))
        } catch {
            seasons[seriesID] = .failed(handle(error))
        }
    }

    public func loadEpisodes(seriesID: String, seasonID: String) async {
        guard let session else { return }
        if case .loaded = episodes[seasonID] {
            return
        }
        episodes[seasonID] = .loading
        do {
            episodes[seasonID] = try await .loaded(fetchEpisodes(seriesID: seriesID, seasonID: seasonID, session: session))
        } catch {
            episodes[seasonID] = .failed(handle(error))
        }
    }

    public func refresh() {
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
