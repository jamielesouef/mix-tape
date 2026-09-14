//  LoadEpochTracker.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

/// Guards a set of concurrent loads against staleness: a sign-out or a refresh starts a
/// fresh epoch, and any load that began under an earlier one is dropped rather than
/// written over newer state.
///
/// One tracker serves every load a service runs, because a refresh must invalidate all of
/// them together, not just the one that triggered it.
@MainActor
final class LoadEpochTracker {
    private(set) var generation = OperationGeneration()
    private let sessionService: SessionService

    init(sessionService: SessionService) {
        self.sessionService = sessionService
    }

    /// Starts a fresh epoch, invalidating every load already in flight.
    func advance() {
        generation = OperationGeneration()
    }

    /// Whether a result that started under `epoch` and `generation` may still be applied.
    func isCurrent(epoch: UserSession, generation: OperationGeneration) -> Bool {
        sessionService.currentSession == epoch && self.generation == generation
    }

    /// Runs `fetch`, mapping any thrown error onto the domain error type. The error
    /// mapping (and any session-expiry it triggers) always runs; only the returned
    /// result is conditional. Returns nil when `epoch`/`generation` have moved on while
    /// the request was in flight — the result, success or failure, is then stale and the
    /// caller drops it rather than writing it over newer state.
    func fetchCurrent<Value>(
        epoch: UserSession,
        generation: OperationGeneration,
        _ fetch: () async throws -> Value
    ) async -> Result<Value, MixtapeError>? {
        do {
            let value = try await fetch()
            return isCurrent(epoch: epoch, generation: generation) ? .success(value) : nil
        } catch {
            let mapped = MixtapeError.mapping(from: error)

            if mapped == .sessionExpired {
                sessionService.handleSessionExpiry()
            }

            return isCurrent(epoch: epoch, generation: generation) ? .failure(mapped) : nil
        }
    }
}
