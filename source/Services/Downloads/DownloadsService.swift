//  DownloadsService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation
import Observation

/// Owns whether each album is downloaded, downloading, waiting for Wi-Fi, or failed.
/// `AlbumDownloadManager` runs the actual transfers; this is the observable front for it.
@MainActor
@Observable
final class DownloadsService {
    // MARK: - Properties

    private(set) var downloads: [String: DownloadState] = [:]

    private let manager: AlbumDownloadManager
    private let fileStore: DownloadFileStore
    private let buildAudioStreamURL: BuildAudioStreamURLUseCase
    private let networkMonitor: NetworkPathMonitor
    private let sessionService: SessionService
    private let settingsService: SettingsService

    // MARK: - Initialization

    init(
        manager: AlbumDownloadManager,
        fileStore: DownloadFileStore,
        buildAudioStreamURL: BuildAudioStreamURLUseCase,
        networkMonitor: NetworkPathMonitor,
        sessionService: SessionService,
        settingsService: SettingsService,
        downloads: [String: DownloadState] = [:]
    ) {
        self.manager = manager
        self.fileStore = fileStore
        self.buildAudioStreamURL = buildAudioStreamURL
        self.networkMonitor = networkMonitor
        self.sessionService = sessionService
        self.settingsService = settingsService
        self.downloads = downloads
    }

    // MARK: - Public API

    var downloadedAlbumIDs: [String] {
        downloads.compactMap { $0.value == .downloaded ? $0.key : nil }
    }

    func state(for albumID: String) -> DownloadState {
        downloads[albumID] ?? .notDownloaded
    }

    /// Rebuilds `downloads` from what is already on disk — called once when a screen that
    /// cares about download state first appears, so state survives an app relaunch.
    func restoreFromDisk() async {
        for albumID in await fileStore.downloadedAlbumIDs() where downloads[albumID] == nil {
            downloads[albumID] = .downloaded
        }
    }

    func start(album: MediaItem, tracks: [MediaItem]) async {
        guard let session = sessionService.currentSession, tracks.isEmpty == false else {
            return
        }
        guard state(for: album.id).isActive == false, state(for: album.id) != .downloaded else {
            return
        }

        if settingsService.settings.downloadsWiFiOnly {
            let status = await networkMonitor.status()

            guard status.isWiFi else {
                downloads[album.id] = .waitingForWiFi
                return
            }
        }

        let managerTracks = tracks.map { track in
            AlbumDownloadManager.Track(
                id: track.id,
                url: buildAudioStreamURL(
                    track: track,
                    session: session,
                    playSessionID: UUID().uuidString
                ).url
            )
        }

        downloads[album.id] = .downloading(progress: 0)

        await manager.start(albumID: album.id, tracks: managerTracks) { [weak self] state in
            await self?.apply(state, albumID: album.id)
        }
    }

    func cancel(albumID: String) async {
        await manager.cancel(albumID: albumID)
        downloads[albumID] = .notDownloaded
    }

    func remove(albumID: String) async {
        await manager.cancel(albumID: albumID)
        try? await fileStore.removeAlbum(albumID: albumID)
        downloads[albumID] = .notDownloaded
    }

    /// Deletes every downloaded file. Used by "Remove All Downloads" in Settings, and by the
    /// sign-out confirmation when downloads exist for the account signing out.
    func removeAll() async {
        for albumID in downloads.keys {
            await manager.cancel(albumID: albumID)
        }

        try? await fileStore.removeAll()
        downloads = [:]
    }

    func bytesOnDisk(albumID: String) async -> Int64 {
        await fileStore.bytesOnDisk(albumID: albumID)
    }

    func totalBytesOnDisk() async -> Int64 {
        await fileStore.totalBytesOnDisk()
    }

    func localAudioURL(albumID: String, trackID: String) async -> URL? {
        await fileStore.localURL(albumID: albumID, trackID: trackID)
    }

    /// Cancels in-flight transfers without deleting anything already on disk — the teardown
    /// shared by an explicit sign-out and a session expiring underneath the app.
    func endSession() async {
        for albumID in downloads.keys where state(for: albumID).isActive {
            await manager.cancel(albumID: albumID)
        }

        downloads = [:]
    }

    // MARK: - Private

    private func apply(_ state: DownloadState, albumID: String) {
        downloads[albumID] = state
    }
}
