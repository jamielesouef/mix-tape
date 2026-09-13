//  AppContainer.swift
//  Mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import UIKit

@MainActor
struct AppContainer {
    let sessionService: SessionService
    let libraryService: LibraryService
    let imageService: ImageService
    let musicPlayerService: MusicPlayerService

    init() {
        let client = Self.makeHTTPClient()
        let sessionStore = KeychainSessionStore()
        let deviceID = (try? sessionStore.deviceID()) ?? UUID().uuidString
        let appVersion = Self.appVersion

        let authRepository = JellyfinAuthRepository(
            client: client,
            deviceID: deviceID,
            appVersion: appVersion
        )
        let libraryRepository = JellyfinLibraryRepository(client: client, appVersion: appVersion)
        let playbackRepository = JellyfinPlaybackRepository(client: client, appVersion: appVersion)

        sessionService = SessionService(
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

        libraryService = LibraryService(
            fetchLibraries: FetchLibrariesUseCase(repository: libraryRepository),
            fetchLibraryItems: FetchLibraryItemsUseCase(repository: libraryRepository),
            fetchItemDetail: FetchItemDetailUseCase(repository: libraryRepository),
            fetchAlbumTracks: FetchAlbumTracksUseCase(repository: libraryRepository),
            sessionService: sessionService
        )

        imageService = ImageService(
            builder: JellyfinImageURLBuilder(),
            sessionService: sessionService
        )

        // Captured locally because a struct initialiser cannot escape `self` into a closure.
        let images = imageService
        let artworkProvider: @Sendable (MediaItem) async -> UIImage? = { track in
            await images.image(for: track, kind: .primary, maxHeight: Self.artworkHeight)
        }

        musicPlayerService = MusicPlayerService(
            controller: AudioPlayerController(),
            buildAudioStreamURL: BuildAudioStreamURLUseCase(repository: playbackRepository),
            reportStart: ReportPlaybackStartUseCase(repository: playbackRepository),
            reportProgress: ReportPlaybackProgressUseCase(repository: playbackRepository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: playbackRepository),
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
}
