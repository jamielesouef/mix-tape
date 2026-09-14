//  QuickConnectCoordinator.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

import Observation

/// Owns the quick-connect handshake and its five-minute poll loop, signalling
/// `onSignedIn` the moment the poll comes back approved.
///
/// `SessionService` still decides what a successful sign-in means for the wider session —
/// this only runs the poll and reports the code, the wait, and the outcome.
@MainActor
@Observable
final class QuickConnectCoordinator {
    private(set) var state: QuickConnectUIState = .idle

    /// Fired the moment a poll comes back approved. `SessionService` sets its own
    /// `state` to `.signedIn` from here.
    var onSignedIn: ((UserSession) -> Void)?

    static let pollInterval: Duration = .seconds(5)
    static let pollTimeout: Duration = .seconds(5 * 60)

    private let startQuickConnect: StartQuickConnectUseCase
    private let pollQuickConnect: PollQuickConnectUseCase
    private let clock: any Clock<Duration>

    /// Exposed at `internal` (not `private`) so tests can await the poll loop's completion.
    @ObservationIgnored var pollTask: Task<Void, Never>?

    init(
        startQuickConnect: StartQuickConnectUseCase,
        pollQuickConnect: PollQuickConnectUseCase,
        clock: any Clock<Duration>,
        initialState: QuickConnectUIState = .idle
    ) {
        self.startQuickConnect = startQuickConnect
        self.pollQuickConnect = pollQuickConnect
        self.clock = clock
        state = initialState
    }

    deinit {
        pollTask?.cancel()
    }

    func start(server: ServerIdentity) async {
        pollTask?.cancel()

        do {
            let handshake = try await startQuickConnect(server: server)

            state = .waiting(code: handshake.code)
            pollTask = Task { [weak self] in
                await self?.poll(secret: handshake.secret, server: server)
            }
        } catch {
            state = .failed(MixtapeError.mapping(from: error))
        }
    }

    func cancel() {
        pollTask?.cancel()
        pollTask = nil

        state = .idle
    }

    // MARK: - Private

    private func poll(secret: String, server: ServerIdentity) async {
        var elapsed: Duration = .zero

        while elapsed < Self.pollTimeout {
            do {
                try await clock.sleep(for: Self.pollInterval)
            } catch {
                return
            }

            elapsed += Self.pollInterval

            do {
                guard
                    let session = try await pollQuickConnect(secret: secret, server: server)
                else {
                    continue
                }
                guard Task.isCancelled == false else {
                    return
                }

                state = .idle
                onSignedIn?(session)
                return
            } catch is CancellationError {
                return
            } catch {
                guard Task.isCancelled == false else {
                    return
                }

                state = .failed(MixtapeError.mapping(from: error))
                return
            }
        }

        guard Task.isCancelled == false else {
            return
        }

        state = .failed(.quickConnectExpired)
    }
}
