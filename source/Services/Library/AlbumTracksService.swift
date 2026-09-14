//  AlbumTracksService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

import Observation

/// Caches an album's track list per album id.
///
/// Shares `LibraryService`'s `LoadEpochTracker` rather than owning one, so a sign-out or a
/// refresh invalidates an in-flight track load the same way it invalidates a page load —
/// one epoch, every load in the wallet answers to it.
@MainActor
@Observable
final class AlbumTracksService {
    private(set) var tracks: [String: LoadState<[MediaItem]>]

    private var tracksInFlight: Set<String> = []

    private let epoch: LoadEpochTracker
    private let fetchAlbumTracks: FetchAlbumTracksUseCase
    private let sessionService: SessionService

    init(
        fetchAlbumTracks: FetchAlbumTracksUseCase,
        sessionService: SessionService,
        epoch: LoadEpochTracker,
        tracks: [String: LoadState<[MediaItem]>] = [:]
    ) {
        self.fetchAlbumTracks = fetchAlbumTracks
        self.sessionService = sessionService
        self.epoch = epoch
        self.tracks = tracks
    }

    func loadTracks(albumID: String) async {
        guard let session = sessionService.currentSession else {
            return
        }

        if case .loaded = tracks[albumID] {
            return
        }

        guard tracksInFlight.contains(albumID) == false else {
            return
        }

        let requestEpoch = session
        let generation = epoch.generation

        tracksInFlight.insert(albumID)
        defer { tracksInFlight.remove(albumID) }

        tracks[albumID] = .loading

        guard
            let result = await epoch.fetchCurrent(epoch: requestEpoch, generation: generation, {
                try await fetchAlbumTracks(albumID: albumID, session: requestEpoch)
            })
        else {
            return
        }

        switch result {
        case let .success(loaded): tracks[albumID] = .loaded(loaded)
        case let .failure(mapped): tracks[albumID] = .failed(mapped)
        }
    }

    func reset() {
        tracks = [:]
    }
}
