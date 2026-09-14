//  SessionService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class SessionService {
    enum State: Equatable, Sendable {
        case loading
        case signedOut
        case signedIn(UserSession)
    }

    // MARK: - Properties

    private(set) var state: State
    private(set) var serverIdentity: ServerIdentity?
    private(set) var error: MixtapeError?
    private(set) var isBusy = false

    private let quickConnectCoordinator: QuickConnectCoordinator
    private let validateServer: ValidateServerUseCase
    private let signInWithPassword: SignInWithPasswordUseCase
    private let restoreSession: RestoreSessionUseCase
    private let signOutUseCase: SignOutUseCase

    @ObservationIgnored var onSessionEnded: ((UserSession) -> Void)?

    // MARK: - Initialization

    init(
        validateServer: ValidateServerUseCase,
        signInWithPassword: SignInWithPasswordUseCase,
        startQuickConnect: StartQuickConnectUseCase,
        pollQuickConnect: PollQuickConnectUseCase,
        restoreSession: RestoreSessionUseCase,
        signOut: SignOutUseCase,
        clock: any Clock<Duration> = ContinuousClock(),
        initialState: State = .loading,
        serverIdentity: ServerIdentity? = nil,
        quickConnect: QuickConnectUIState = .idle,
        error: MixtapeError? = nil
    ) {
        self.validateServer = validateServer
        self.signInWithPassword = signInWithPassword
        self.restoreSession = restoreSession
        signOutUseCase = signOut
        quickConnectCoordinator = QuickConnectCoordinator(
            startQuickConnect: startQuickConnect,
            pollQuickConnect: pollQuickConnect,
            clock: clock,
            initialState: quickConnect
        )
        state = initialState
        self.serverIdentity = serverIdentity
        self.error = error

        quickConnectCoordinator.onSignedIn = { [weak self] session in
            self?.state = .signedIn(session)
        }
    }

    // MARK: - Public API

    /// The signed-in session, or nil when signed out or still restoring.
    ///
    /// The single source of truth for "does a session currently exist" — every other
    /// service reads this rather than re-deriving it from `state`.
    var currentSession: UserSession? {
        if case let .signedIn(session) = state {
            return session
        }
        return nil
    }

    var quickConnect: QuickConnectUIState {
        quickConnectCoordinator.state
    }

    /// Exposed so tests can await the quick-connect poll loop's completion.
    var pollTask: Task<Void, Never>? {
        quickConnectCoordinator.pollTask
    }

    func restore() async {
        do {
            if let session = try restoreSession() {
                state = .signedIn(session)
            } else {
                state = .signedOut
            }
        } catch {
            self.error = MixtapeError.mapping(from: error)
            state = .signedOut
        }
    }

    func validateServer(urlText: String) async {
        isBusy = true
        defer { isBusy = false }

        error = nil

        do {
            serverIdentity = try await validateServer(urlText: urlText)
        } catch {
            self.error = MixtapeError.mapping(from: error)
        }
    }

    func signIn(userName: String, password: String) async {
        guard let server = serverIdentity else {
            return
        }

        isBusy = true
        defer { isBusy = false }

        error = nil

        do {
            let session = try await signInWithPassword(
                userName: userName,
                password: password,
                server: server
            )

            state = .signedIn(session)
        } catch {
            handle(error)
        }
    }

    func startQuickConnect() async {
        guard let server = serverIdentity else {
            return
        }

        error = nil

        await quickConnectCoordinator.start(server: server)
    }

    func cancelQuickConnect() {
        quickConnectCoordinator.cancel()
    }

    func clearServer() {
        cancelQuickConnect()

        serverIdentity = nil
        error = nil
    }

    func signOut() {
        do {
            try signOutUseCase()
            error = nil
        } catch {
            self.error = MixtapeError.mapping(from: error)
        }

        endSession(clearingServer: true)
    }

    func handleSessionExpiry() {
        try? signOutUseCase()
        error = .sessionExpired

        endSession(clearingServer: false)
    }

    // MARK: - Private

    private func handle(_ error: any Error) {
        let mapped = MixtapeError.mapping(from: error)

        if mapped == .sessionExpired {
            handleSessionExpiry()
        } else {
            self.error = mapped
        }
    }

    /// The shared part of ending a session: cancels any in-flight quick-connect poll, resets
    /// to signed out, and notifies `onSessionEnded`. `signOut` also forgets the server so the
    /// user re-enters it; a session-expiry leaves it in place so re-signing-in needs no retyping.
    private func endSession(clearingServer: Bool) {
        quickConnectCoordinator.cancel()

        let endedSession = currentSession

        state = .signedOut

        if clearingServer {
            serverIdentity = nil
        }

        if let endedSession {
            onSessionEnded?(endedSession)
        }
    }
}
