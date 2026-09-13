//  SessionService+Placeholder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

extension SessionService {
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
