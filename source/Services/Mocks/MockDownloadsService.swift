//  MockDownloadsService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation

#if DEBUG

    @MainActor
    enum MockDownloadsService {
        static func make(
            downloads: [String: DownloadState] = [:],
            sessionService: SessionService = MockSessionService.signedIn(),
            settingsService: SettingsService = MockSettingsService.make()
        ) -> DownloadsService {
            let fileStore = DownloadFileStore(root: Self.previewRoot())

            return DownloadsService(
                manager: AlbumDownloadManager(fileStore: fileStore),
                fileStore: fileStore,
                buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: MockPlaybackRepository()),
                networkMonitor: NetworkPathMonitor(),
                sessionService: sessionService,
                settingsService: settingsService,
                downloads: downloads
            )
        }

        static func idle() -> DownloadsService {
            make()
        }

        static func downloading() -> DownloadsService {
            make(downloads: ["album-1": .downloading(progress: 0.4)])
        }

        static func downloaded() -> DownloadsService {
            make(downloads: ["album-1": .downloaded])
        }

        // MARK: - Private

        private static func previewRoot() -> URL {
            FileManager.default.temporaryDirectory.appending(path: "mixtape-preview-downloads")
        }
    }
#endif
