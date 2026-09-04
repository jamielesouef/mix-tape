//  SessionService+Placeholder.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeUseCase

public extension SessionService {
    /// `@Entry` default. Never used by a running app — the composition root always injects one.
    /// Debug builds use the preview mock; release builds, which carry no `Mock*` type (slice 013),
    /// build the same service over the inert `Placeholder*` collaborators.
    static let placeholder: SessionService = {
        #if DEBUG
            return MockSessionService.signedOut()
        #else
            let repository = PlaceholderAuthRepository()
            let store = PlaceholderSessionStore()
            return SessionService(
                validateServer: ValidateServerUseCase(repository: repository),
                signInWithPassword: SignInWithPasswordUseCase(repository: repository, store: store),
                startQuickConnect: StartQuickConnectUseCase(repository: repository),
                pollQuickConnect: PollQuickConnectUseCase(repository: repository, store: store),
                restoreSession: RestoreSessionUseCase(store: store),
                signOut: SignOutUseCase(store: store),
                initialState: .signedOut,
            )
        #endif
    }()
}
