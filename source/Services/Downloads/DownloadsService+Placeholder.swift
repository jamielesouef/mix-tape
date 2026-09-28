//  DownloadsService+Placeholder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

extension DownloadsService {
    static let placeholder: DownloadsService = {
        #if DEBUG
            return MockDownloadsService.idle()
        #else
            let fileStore = DownloadFileStore()
            return DownloadsService(
                manager: AlbumDownloadManager(fileStore: fileStore),
                fileStore: fileStore,
                buildAudioStreamURL: BuildAudioStreamURLUseCase(
                    repository: PlaceholderPlaybackRepository()
                ),
                networkMonitor: NetworkPathMonitor(),
                sessionService: .placeholder,
                settingsService: .placeholder
            )
        #endif
    }()
}
