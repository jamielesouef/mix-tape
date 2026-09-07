//  SessionService.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import MixtapeUseCase
import Observation

/// Engineering doc §6. The only writer of session state, and the single place `.sessionExpired`
/// is handled.
@Observable
public final class SessionService {
    public enum State: Equatable, Sendable {
        case loading
        case signedOut
        case signedIn(UserSession)
    }

    public private(set) var state: State
    public private(set) var serverIdentity: ServerIdentity?
    public private(set) var error: MixtapeError?
    /// Decisions 24 and 28: never optional.
    public private(set) var quickConnect: QuickConnectUIState
    public private(set) var isBusy = false

    private let validateServer: ValidateServerUseCase
    private let signInWithPassword: SignInWithPasswordUseCase
    private let startQuickConnect: StartQuickConnectUseCase
    private let pollQuickConnect: PollQuickConnectUseCase
    private let restoreSession: RestoreSessionUseCase
    private let signOutUseCase: SignOutUseCase
    private let clock: any Clock<Duration>

    static let pollInterval: Duration = .seconds(5)
    static let pollTimeout: Duration = .seconds(5 * 60)

    @ObservationIgnored var pollTask: Task<Void, Never>?

    public init(
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
        error: MixtapeError? = nil,
    ) {
        self.validateServer = validateServer
        self.signInWithPassword = signInWithPassword
        self.startQuickConnect = startQuickConnect
        self.pollQuickConnect = pollQuickConnect
        self.restoreSession = restoreSession
        signOutUseCase = signOut
        self.clock = clock
        state = initialState
        self.serverIdentity = serverIdentity
        self.quickConnect = quickConnect
        self.error = error
    }

    deinit {
        pollTask?.cancel()
    }

    public func restore() async {
        do {
            if let session = try restoreSession() {
                state = .signedIn(session)
            } else {
                state = .signedOut
            }
        } catch {
            self.error = Self.mixtapeError(error)
            state = .signedOut
        }
    }

    public func validateServer(urlText: String) async {
        isBusy = true
        defer { isBusy = false }
        error = nil
        do {
            serverIdentity = try await validateServer(urlText: urlText)
        } catch {
            self.error = Self.mixtapeError(error)
        }
    }

    public func signIn(userName: String, password: String) async {
        guard let server = serverIdentity else { return }
        isBusy = true
        defer { isBusy = false }
        error = nil
        do {
            let session = try await signInWithPassword(userName: userName, password: password, server: server)
            state = .signedIn(session)
        } catch {
            handle(error)
        }
    }

    /// Requests a code, then polls every 5 s for at most 5 min on the injected clock (decision 29 on expiry).
    public func startQuickConnect() async {
        guard let server = serverIdentity else { return }
        pollTask?.cancel()
        error = nil
        do {
            let handshake = try await startQuickConnect(server: server)
            quickConnect = .waiting(code: handshake.code)
            pollTask = Task { [weak self] in
                await self?.poll(secret: handshake.secret, server: server)
            }
        } catch {
            quickConnect = .failed(Self.mixtapeError(error))
        }
    }

    public func cancelQuickConnect() {
        pollTask?.cancel()
        pollTask = nil
        quickConnect = .idle
    }

    /// Back to server entry before any sign-in (slice 019): `SignInFlow` shows `ServerEntryScreen`
    /// whenever `serverIdentity` is nil.
    public func clearServer() {
        cancelQuickConnect()
        serverIdentity = nil
        error = nil
    }

    public func signOut() {
        pollTask?.cancel()
        pollTask = nil
        do {
            try signOutUseCase()
            error = nil
        } catch {
            self.error = Self.mixtapeError(error)
        }
        state = .signedOut
        serverIdentity = nil
        quickConnect = .idle
    }

    /// Clears the stored session and returns to `.signedOut`, keeping the server so the user
    /// can sign in again. Every service routes a `.sessionExpired` here.
    public func handleSessionExpiry() {
        pollTask?.cancel()
        pollTask = nil
        try? signOutUseCase() // the session is already invalid; a Keychain failure changes nothing about that
        state = .signedOut
        quickConnect = .idle
        error = .sessionExpired
    }

    private func poll(secret: String, server: ServerIdentity) async {
        var elapsed: Duration = .zero
        while elapsed < Self.pollTimeout {
            do {
                try await clock.sleep(for: Self.pollInterval)
            } catch {
                return // cancelled
            }
            elapsed += Self.pollInterval
            do {
                if let session = try await pollQuickConnect(secret: secret, server: server) {
                    guard Task.isCancelled == false else { return }
                    state = .signedIn(session)
                    quickConnect = .idle
                    return
                }
            } catch is CancellationError {
                return
            } catch {
                guard Task.isCancelled == false else { return }
                quickConnect = .failed(Self.mixtapeError(error))
                return
            }
        }
        guard Task.isCancelled == false else { return }
        quickConnect = .failed(.quickConnectExpired)
    }

    private func handle(_ error: any Error) {
        let mapped = Self.mixtapeError(error)
        if mapped == .sessionExpired {
            handleSessionExpiry()
        } else {
            self.error = mapped
        }
    }

    private static func mixtapeError(_ error: any Error) -> MixtapeError {
        (error as? MixtapeError) ?? .transport(error.localizedDescription)
    }
}
