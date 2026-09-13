//  AppContainer.swift
//  Mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

@MainActor
struct AppContainer {
    let sessionService: SessionService
    let libraryService: LibraryService
    let seriesService: SeriesService
    let imageService: ImageService
    let videoPlaybackService: VideoPlaybackService
    let musicPlayerService: MusicPlayerService

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        let client = JellyfinHTTPClient(session: URLSession(configuration: configuration), deviceName: DeviceName.current)

        let sessionStore = KeychainSessionStore()
        let deviceID = (try? sessionStore.deviceID()) ?? UUID().uuidString
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"

        let authRepository = JellyfinAuthRepository(client: client, deviceID: deviceID, appVersion: appVersion)

        sessionService = SessionService(
            validateServer: ValidateServerUseCase(repository: authRepository),
            signInWithPassword: SignInWithPasswordUseCase(repository: authRepository, store: sessionStore),
            startQuickConnect: StartQuickConnectUseCase(repository: authRepository),
            pollQuickConnect: PollQuickConnectUseCase(repository: authRepository, store: sessionStore),
            restoreSession: RestoreSessionUseCase(store: sessionStore),
            signOut: SignOutUseCase(store: sessionStore),
        )

        let libraryRepository = JellyfinLibraryRepository(client: client, appVersion: appVersion)
        libraryService = LibraryService(
            fetchLibraries: FetchLibrariesUseCase(repository: libraryRepository),
            fetchLibraryItems: FetchLibraryItemsUseCase(repository: libraryRepository),
            fetchItemDetail: FetchItemDetailUseCase(repository: libraryRepository),
            fetchAlbumTracks: FetchAlbumTracksUseCase(repository: libraryRepository),
            fetchContinueWatching: FetchContinueWatchingUseCase(repository: libraryRepository),
            sessionService: sessionService,
        )
        seriesService = SeriesService(
            fetchSeasons: FetchSeasonsUseCase(repository: libraryRepository),
            fetchEpisodes: FetchEpisodesUseCase(repository: libraryRepository),
            sessionService: sessionService,
        )
        imageService = ImageService(builder: JellyfinImageURLBuilder(), sessionService: sessionService)

        let playbackRepository = JellyfinPlaybackRepository(client: client, appVersion: appVersion, deviceProfile: Self.deviceProfile)
        videoPlaybackService = VideoPlaybackService(
            resolveVideo: ResolveVideoPlaybackUseCase(repository: playbackRepository),
            reportStart: ReportPlaybackStartUseCase(repository: playbackRepository),
            reportProgress: ReportPlaybackProgressUseCase(repository: playbackRepository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: playbackRepository),
            sessionService: sessionService,
            makeController: { method in
                switch method {
                case .directAVPlayer, .transcodeHLS: AVPlayerController()
                case .directVLC: VLCPlayerController()
                }
            },
            libraryService: libraryService,
        )

        let imageServiceRef = imageService
        musicPlayerService = MusicPlayerService(
            controller: AudioPlayerController(),
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: playbackRepository),
            reportStart: ReportPlaybackStartUseCase(repository: playbackRepository),
            reportProgress: ReportPlaybackProgressUseCase(repository: playbackRepository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: playbackRepository),
            sessionService: sessionService,
            artworkProvider: { track in await imageServiceRef.image(for: track, kind: .primary, maxHeight: 600) },
        )

        let libraryServiceRef = libraryService
        let seriesServiceRef = seriesService
        let musicPlayerServiceRef = musicPlayerService
        let videoPlaybackServiceRef = videoPlaybackService
        sessionService.onSessionEnded = { session in
            libraryServiceRef.endSession()
            seriesServiceRef.endSession()
            musicPlayerServiceRef.endSession(session)
            videoPlaybackServiceRef.endSession(session)
        }
    }

    private static var deviceProfile: DeviceProfile {
        #if DEBUG
            if CommandLine.arguments.contains("-mixtape-force-transcode") {
                return .forceTranscode
            }
        #endif
        return .permissive
    }
}
