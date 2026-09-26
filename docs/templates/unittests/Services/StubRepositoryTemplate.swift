// TEMPLATE — Stub repository for a Service test. Copy, rename, delete this header.
//
// Layer: <TestTarget>/Stubs/Stub<Name>Repository.swift
//
// - `actor`, not `final class`: it is called from the service's async
//   methods and read back by the test, so it needs its own isolation.
//   Conforms to the real `*RepositoryProtocol`, nothing more.
// - `Result<Success, Failure>` per method, configurable at init AND mid-test
//   (`updateFetchItemsResult`). Resolved with `try result.get()`. `Result`
//   stays confined to test doubles; production never uses it for flow.
// - Call-count SPY (`private(set) var fetchItemsCallCount`) so a test can
//   assert HOW MANY TIMES the service called through, not only the final
//   state. "start() only fetches once" needs the count.
// - GATE, for the rare test that must act while a call is in flight.
//   `closeGate()` parks every `fetchItems` on a continuation until
//   `openGate()`. The result is captured BEFORE parking, so two parked
//   calls can return different values. `waitUntilFetchCount(reaches:)` is
//   how the test knows a call has arrived without polling: it returns at
//   once if the count is already there, otherwise parks on a continuation
//   the next `fetchItems` resumes. No yield loop anywhere.

import Foundation
@testable import ExampleApp

actor StubExampleFeatureRepository: ExampleFeatureRepositoryProtocol {
    // MARK: - Types

    private struct CountWaiter {
        let count: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    // MARK: - Configurable results

    private var fetchItemsResult: Result<[ExampleFeatureItem], ExampleFeatureError>

    // MARK: - Call spies

    private(set) var fetchItemsCallCount = 0

    // MARK: - Gate

    private var isGateClosed = false
    private var gateWaiters: [CheckedContinuation<Void, Never>] = []
    private var countWaiters: [CountWaiter] = []

    // MARK: - Init

    init(fetchItemsResult: Result<[ExampleFeatureItem], ExampleFeatureError> = .success([])) {
        self.fetchItemsResult = fetchItemsResult
    }

    // MARK: - ExampleFeatureRepositoryProtocol

    func fetchItems() async throws(ExampleFeatureError) -> [ExampleFeatureItem] {
        fetchItemsCallCount += 1
        let result = fetchItemsResult
        resumeCountWaiters()

        if isGateClosed {
            await withCheckedContinuation { continuation in
                gateWaiters.append(continuation)
            }
        }

        return try result.get()
    }

    // MARK: - Test configuration

    func updateFetchItemsResult(_ result: Result<[ExampleFeatureItem], ExampleFeatureError>) {
        fetchItemsResult = result
    }

    func closeGate() {
        isGateClosed = true
    }

    func openGate() {
        isGateClosed = false
        let waiters = gateWaiters
        gateWaiters = []
        for waiter in waiters {
            waiter.resume()
        }
    }

    func waitUntilFetchCount(reaches count: Int) async {
        guard fetchItemsCallCount < count else {
            return
        }

        await withCheckedContinuation { continuation in
            countWaiters.append(CountWaiter(count: count, continuation: continuation))
        }
    }

    // MARK: - Private

    private func resumeCountWaiters() {
        let ready = countWaiters.filter { $0.count <= fetchItemsCallCount }
        countWaiters.removeAll { $0.count <= fetchItemsCallCount }
        for waiter in ready {
            waiter.continuation.resume()
        }
    }
}
