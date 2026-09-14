//  AppContainer.swift
//  Mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import UIKit

@MainActor
struct AppContainer {
    // MARK: - Properties

    let sessionService: SessionService
    let libraryService: LibraryService
    let imageService: ImageService
    let musicPlayerService: MusicPlayerService

    // MARK: - Initialization

    init() {
        let client = Self.makeHTTPClient()
        let sessionStore = KeychainSessionStore()
        let deviceID = (try? sessionStore.deviceID()) ?? UUID().uuidString
        let appVersion = Self.appVersion

        let repositories = Self.makeRepositories(
            client: client,
            deviceID: deviceID,
            appVersion: appVersion
        )

        sessionService = Self.makeSessionService(
            authRepository: repositories.auth,
            sessionStore: sessionStore
        )
        libraryService = Self.makeLibraryService(
            libraryRepository: repositories.library,
            sessionService: sessionService
        )
        imageService = Self.makeImageService(sessionService: sessionService)

        // Captured locally because a struct initialiser cannot escape `self` into a closure.
        let images = imageService
        let artworkProvider: @Sendable (MediaItem) async -> UIImage? = { track in
            await images.image(for: track, kind: .primary, maxHeight: Self.artworkHeight)
        }

        musicPlayerService = Self.makeMusicPlayerService(
            playbackRepository: repositories.playback,
            sessionService: sessionService,
            artworkProvider: artworkProvider
        )

        let libraries = libraryService
        let music = musicPlayerService

        sessionService.onSessionEnded = { session in
            libraries.endSession()
            music.endSession(session)
        }
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
            deviceName: DeviceName.current
        )
    }

    private struct Repositories {
        let auth: JellyfinAuthRepository
        let library: JellyfinLibraryRepository
        let playback: JellyfinPlaybackRepository
    }

    private static func makeRepositories(
        client: JellyfinHTTPClient,
        deviceID: String,
        appVersion: String
    ) -> Repositories {
        Repositories(
            auth: JellyfinAuthRepository(
                client: client,
                deviceID: deviceID,
                appVersion: appVersion
            ),
            library: JellyfinLibraryRepository(client: client, appVersion: appVersion),
            playback: JellyfinPlaybackRepository(client: client, appVersion: appVersion)
        )
    }

    private static func makeSessionService(
        authRepository: JellyfinAuthRepository,
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
        libraryRepository: JellyfinLibraryRepository,
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

    private static func makeImageService(sessionService: SessionService) -> ImageService {
        ImageService(builder: JellyfinImageURLBuilder(), sessionService: sessionService)
    }

    private static func makeMusicPlayerService(
        playbackRepository: JellyfinPlaybackRepository,
        sessionService: SessionService,
        artworkProvider: @escaping @Sendable (MediaItem) async -> UIImage?
    ) -> MusicPlayerService {
        MusicPlayerService(
            controller: AudioPlayerController(),
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: playbackRepository),
            reportStart: ReportPlaybackStartUseCase(repository: playbackRepository),
            reportProgress: ReportPlaybackProgressUseCase(repository: playbackRepository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: playbackRepository),
            sessionService: sessionService,
            artworkProvider: artworkProvider
        )
    }
}
