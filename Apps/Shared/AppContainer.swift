//  AppContainer.swift
//  Mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeData
import MixtapeDomain
import MixtapeInfrastructure
import MixtapePresentation
import MixtapeServices
import MixtapeUseCase

/// Composition root (engineering doc §10): the one place that sees all six layers.
/// Builds the client, then repositories, then use cases, then services — by hand.
@MainActor
struct AppContainer {
    let sessionService: SessionService
    let libraryService: LibraryService
    let seriesService: SeriesService
    let imageService: ImageService
    let videoPlaybackService: VideoPlaybackService

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        let client = JellyfinHTTPClient(session: URLSession(configuration: configuration), deviceName: DeviceName.current)

        let sessionStore = KeychainSessionStore()
        // A Keychain that cannot even hold the device id is broken beyond what this app can fix;
        // a per-launch id keeps the app usable for the session.
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
            sessionService: sessionService,
            makeController: { method in
                switch method {
                case .directAVPlayer, .transcodeHLS: AVPlayerController()
                case .directVLC: nil // VLCPlayerController lands in slice 007
                }
            },
        )
    }

    /// The shipped profile is always `permissive`. In DEBUG builds the `-mixtape-force-transcode`
    /// launch argument swaps in the restrictive profile so AC8 can be demonstrated live (fork F3).
    private static var deviceProfile: DeviceProfile {
        #if DEBUG
            if CommandLine.arguments.contains("-mixtape-force-transcode") {
                return .forceTranscode
            }
        #endif
        return .permissive
    }
}
