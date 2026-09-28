//  AlbumDownloadManager.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation

/// Runs one album's track downloads to completion, sequentially, reporting a coarse
/// per-track progress. Cancelling the album cancels whichever track is in flight.
actor AlbumDownloadManager {
    struct Track: Sendable {
        let id: String
        let url: URL
    }

    private var activeTasks: [String: Task<Void, Never>] = [:]
    private let session: URLSession
    private let fileStore: DownloadFileStore

    init(session: URLSession = .shared, fileStore: DownloadFileStore) {
        self.session = session
        self.fileStore = fileStore
    }

    func start(
        albumID: String,
        tracks: [Track],
        onProgress: @escaping @Sendable (DownloadState) async -> Void
    ) {
        guard activeTasks[albumID] == nil else {
            return
        }

        activeTasks[albumID] = Task { [weak self] in
            await self?.run(albumID: albumID, tracks: tracks, onProgress: onProgress)
        }
    }

    func cancel(albumID: String) {
        activeTasks[albumID]?.cancel()
        activeTasks[albumID] = nil
    }

    // MARK: - Private

    private func run(
        albumID: String,
        tracks: [Track],
        onProgress: @Sendable (DownloadState) async -> Void
    ) async {
        for (index, track) in tracks.enumerated() {
            guard Task.isCancelled == false else {
                activeTasks[albumID] = nil
                return
            }

            await onProgress(.downloading(progress: Double(index) / Double(tracks.count)))

            do {
                let (tempURL, response) = try await session.download(from: track.url)

                guard Self.isSuccess(response) else {
                    throw MixtapeError.transport("Download failed for \(track.id)")
                }

                try await fileStore.store(tempURL: tempURL, albumID: albumID, trackID: track.id)
            } catch {
                guard Task.isCancelled == false else {
                    activeTasks[albumID] = nil
                    return
                }

                await onProgress(.failed(MixtapeError.mapping(from: error)))
                activeTasks[albumID] = nil
                return
            }
        }

        await onProgress(.downloaded)
        activeTasks[albumID] = nil
    }

    private static func isSuccess(_ response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else {
            // A file:// response (the mock server's bundled sample) carries no status code.
            return true
        }

        return (200 ... 299).contains(http.statusCode)
    }
}
