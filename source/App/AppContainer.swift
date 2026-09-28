//  AppContainer.swift
//  Mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import JellyfinKit
import UIKit

@MainActor
struct AppContainer {
    /// The one switch between a real Jellyfin server and the bundled mock server. Every
    /// repository sits behind the same `*RepositoryProtocol` seam either way — this line is
    /// the only thing that changes which side of it the app talks to.
    private static let backend: ServerBackend = .mockServer

    private enum ServerBackend {
        case liveJellyfin
        case mockServer
    }

    // MARK: - Properties

    let sessionService: SessionService
    let libraryService: LibraryService
    let imageService: ImageService
    let musicPlayerService: MusicPlayerService
    let settingsService: SettingsService
    let downloadsService: DownloadsService
    let walletsService: WalletsService
    let searchService: SearchService

    // MARK: - Initialization

    init() {
        let client = Self.makeHTTPClient()
        let sessionStore = KeychainSessionStore()
        let deviceID = (try? sessionStore.deviceID()) ?? UUID().uuidString

        let repositories = Self.makeRepositories(
            client: client,
            deviceID: deviceID,
            appVersion: Self.appVersion
        )

        sessionService = Self.makeSessionService(
            authRepository: repositories.auth,
            sessionStore: sessionStore
        )
        libraryService = Self.makeLibraryService(
            libraryRepository: repositories.library,
            sessionService: sessionService
        )
        imageService = Self.makeImageService(
            builder: repositories.imageURLBuilder,
            sessionService: sessionService
        )
        settingsService = SettingsService(store: UserDefaultsLocalSettingsStore())

        let networkMonitor = NetworkPathMonitor()

        downloadsService = Self.makeDownloadsService(
            playbackRepository: repositories.playback,
            sessionService: sessionService,
            settingsService: settingsService,
            networkMonitor: networkMonitor
        )

        musicPlayerService = Self.makeMusicPlayerService(
            repositories: repositories,
            sessionService: sessionService,
            settingsService: settingsService,
            imageService: imageService,
            downloadsService: downloadsService
        )

        walletsService = Self.makeWalletsService(
            libraryService: libraryService,
            downloadsService: downloadsService,
            settingsService: settingsService
        )
        searchService = Self.makeSearchService(
            searchRepository: repositories.search,
            sessionService: sessionService,
            downloadsService: downloadsService,
            networkMonitor: networkMonitor
        )

        Self.wireSessionTeardown(
            sessionService: sessionService,
            libraryService: libraryService,
            musicPlayerService: musicPlayerService,
            walletsService: walletsService,
            downloadsService: downloadsService
        )
    }

    // MARK: - Private

    private static let requestTimeout: TimeInterval = 15

    /// Lock screen and control centre artwork is shown large, so it is fetched large.
    private static let artworkHeight = 600

    private static var appVersion: String {
        Bundle.main
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private static func makeHTTPClient() -> JellyfinHTTPClient {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout

        return JellyfinHTTPClient(
            session: URLSession(configuration: configuration),
            clientName: "mixtape",
            deviceName: DeviceName.current
        )
    }

    private struct Repositories {
        let auth: any AuthRepositoryProtocol
        let library: any LibraryRepositoryProtocol
        let playback: any PlaybackRepositoryProtocol
        let search: any SearchRepositoryProtocol
        let imageURLBuilder: any ImageURLBuilderProtocol
    }

    private static func makeRepositories(
        client: JellyfinHTTPClient,
        deviceID: String,
        appVersion: String
    ) -> Repositories {
        switch backend {
        case .liveJellyfin:
            Repositories(
                auth: JellyfinAuthRepository(client: client, deviceID: deviceID, appVersion: appVersion),
                library: JellyfinLibraryRepository(client: client, appVersion: appVersion),
                playback: JellyfinPlaybackRepository(client: client, appVersion: appVersion),
                search: MockServerSearchRepository(),
                imageURLBuilder: JellyfinImageURLBuilder()
            )
        case .mockServer:
            Repositories(
                auth: MockServerAuthRepository(),
                library: MockServerLibraryRepository(),
                playback: MockServerPlaybackRepository(),
                search: MockServerSearchRepository(),
                imageURLBuilder: MockServerImageURLBuilder()
            )
        }
    }

    private static func makeSessionService(
        authRepository: any AuthRepositoryProtocol,
        sessionStore: KeychainSessionStore
    ) -> SessionService {
        SessionService(
            validateServer: ValidateServerUseCase(repository: authRepository),
            signInWithPassword: SignInWithPasswordUseCase(
                repository: authRepository,
                store: sessionStore
            ),
            startQuickConnect: StartQuickConnectUseCase(repository: authRepository),
            pollQuickConnect: PollQuickConnectUseCase(
                repository: authRepository,
                store: sessionStore
            ),
            restoreSession: RestoreSessionUseCase(store: sessionStore),
            signOut: SignOutUseCase(store: sessionStore)
        )
    }

    private static func makeLibraryService(
        libraryRepository: any LibraryRepositoryProtocol,
        sessionService: SessionService
    ) -> LibraryService {
        LibraryService(
            fetchLibraries: FetchLibrariesUseCase(repository: libraryRepository),
            fetchLibraryItems: FetchLibraryItemsUseCase(repository: libraryRepository),
            fetchItemDetail: FetchItemDetailUseCase(repository: libraryRepository),
            fetchAlbumTracks: FetchAlbumTracksUseCase(repository: libraryRepository),
            sessionService: sessionService
        )
    }

    private static func makeImageService(
        builder: any ImageURLBuilderProtocol,
        sessionService: SessionService
    ) -> ImageService {
        ImageService(builder: builder, sessionService: sessionService)
    }

    private static func makeMusicPlayerService(
        repositories: Repositories,
        sessionService: SessionService,
        settingsService: SettingsService,
        imageService: ImageService,
        downloadsService: DownloadsService
    ) -> MusicPlayerService {
        let playbackRepository = repositories.playback
        let artworkProvider: @Sendable (MediaItem) async -> UIImage? = { track in
            await imageService.image(for: track, kind: .primary, maxHeight: artworkHeight)
        }
        let localAudioURLProvider: @Sendable (MediaItem) async -> URL? = { track in
            guard let albumID = track.albumID else {
                return nil
            }

            return await downloadsService.localAudioURL(albumID: albumID, trackID: track.id)
        }

        return MusicPlayerService(
            controller: AudioPlayerController(),
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: playbackRepository),
            reportStart: ReportPlaybackStartUseCase(repository: playbackRepository),
            reportProgress: ReportPlaybackProgressUseCase(repository: playbackRepository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: playbackRepository),
            sessionService: sessionService,
            settingsService: settingsService,
            fetchAlbumTracks: FetchAlbumTracksUseCase(repository: repositories.library),
            artworkProvider: artworkProvider,
            localAudioURLProvider: localAudioURLProvider
        )
    }

    private static func makeDownloadsService(
        playbackRepository: any PlaybackRepositoryProtocol,
        sessionService: SessionService,
        settingsService: SettingsService,
        networkMonitor: NetworkPathMonitor
    ) -> DownloadsService {
        let fileStore = DownloadFileStore()

        return DownloadsService(
            manager: AlbumDownloadManager(fileStore: fileStore),
            fileStore: fileStore,
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: playbackRepository),
            networkMonitor: networkMonitor,
            sessionService: sessionService,
            settingsService: settingsService
        )
    }

    private static func makeWalletsService(
        libraryService: LibraryService,
        downloadsService: DownloadsService,
        settingsService: SettingsService
    ) -> WalletsService {
        let walletsStore = UserDefaultsWalletsStore()

        return WalletsService(
            libraryService: libraryService,
            downloadsService: downloadsService,
            settingsService: settingsService,
            loadPersonalWallets: LoadPersonalWalletsUseCase(store: walletsStore),
            savePersonalWallets: SavePersonalWalletsUseCase(store: walletsStore),
            loadRandomWalletMode: LoadRandomWalletModeUseCase(store: walletsStore),
            saveRandomWalletMode: SaveRandomWalletModeUseCase(store: walletsStore)
        )
    }

    private static func makeSearchService(
        searchRepository: any SearchRepositoryProtocol,
        sessionService: SessionService,
        downloadsService: DownloadsService,
        networkMonitor: NetworkPathMonitor
    ) -> SearchService {
        SearchService(
            search: SearchLibraryUseCase(repository: searchRepository),
            sessionService: sessionService,
            downloadsService: downloadsService,
            networkMonitor: networkMonitor
        )
    }

    /// `SessionService` holds no reference to the other services; this is the one place all
    /// six layers are visible, so it is the one place that can fan a session ending out to
    /// each service's own teardown.
    private static func wireSessionTeardown(
        sessionService: SessionService,
        libraryService: LibraryService,
        musicPlayerService: MusicPlayerService,
        walletsService: WalletsService,
        downloadsService: DownloadsService
    ) {
        sessionService.onSessionEnded = { session in
            libraryService.endSession()
            musicPlayerService.endSession(session)
            walletsService.endSession()
            Task { await downloadsService.endSession() }
        }
    }
}
