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
    }
}
