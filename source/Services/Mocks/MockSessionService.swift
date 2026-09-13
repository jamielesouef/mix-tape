//  MockSessionService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG

    public enum MockSessionService {
        public static func make(
            state: SessionService.State = .signedOut,
            serverIdentity: ServerIdentity? = nil,
            quickConnect: QuickConnectUIState = .idle,
            error: MixtapeError? = nil,
            repository: MockAuthRepository = MockAuthRepository(),
            store: MockSessionStore = MockSessionStore(),
        ) -> SessionService {
            SessionService(
                validateServer: ValidateServerUseCase(repository: repository),
                signInWithPassword: SignInWithPasswordUseCase(repository: repository, store: store),
                startQuickConnect: StartQuickConnectUseCase(repository: repository),
                pollQuickConnect: PollQuickConnectUseCase(repository: repository, store: store),
                restoreSession: RestoreSessionUseCase(store: store),
                signOut: SignOutUseCase(store: store),
                initialState: state,
                serverIdentity: serverIdentity,
                quickConnect: quickConnect,
                error: error,
            )
        }

        public static func loading() -> SessionService {
            make(state: .loading)
        }

        public static func signedOut() -> SessionService {
            make()
        }

        public static func serverValidated() -> SessionService {
            make(serverIdentity: MockAuthRepository.sampleServer)
        }

        public static func signedIn() -> SessionService {
            make(state: .signedIn(MockAuthRepository.sampleSession), serverIdentity: MockAuthRepository.sampleServer)
        }

        public static func failed(_ error: MixtapeError, serverIdentity: ServerIdentity? = nil) -> SessionService {
            make(serverIdentity: serverIdentity, error: error)
        }

        public static func signInFailed(_ error: MixtapeError) -> SessionService {
            make(serverIdentity: MockAuthRepository.sampleServer, error: error)
        }

        public static func quickConnectWaiting(code: String = "123456") -> SessionService {
            make(serverIdentity: MockAuthRepository.sampleServer, quickConnect: .waiting(code: code))
        }

        public static func quickConnectFailed(_ error: MixtapeError) -> SessionService {
            make(serverIdentity: MockAuthRepository.sampleServer, quickConnect: .failed(error))
        }
    }
#endif
