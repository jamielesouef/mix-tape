// TEMPLATE — Service (MV, not MVVM). Copy, rename, delete this header.
//
// Layer: Services/<Name>Service.swift
//
// - `@MainActor @Observable final class`. A SERVICE, not a ViewModel:
//   `class *ViewModel`, `ObservableObject` and `@Published` do not appear in
//   new code.
// - Sole writer of its own state. Every loading flag is `private`; the view
//   sees ONE derived `loadState`, switched on exhaustively. The derivation
//   is a `switch` over a tuple of the raw flags so every case's full
//   precondition is on its own line and the compiler checks exhaustiveness.
//   `LoadState` is `Equatable` so a test can `#expect(state == .empty)`.
// - Off-main work happens in the injected repository, which is `Sendable`
//   and not `@MainActor`. The service awaits it; only the assignment of
//   finished state touches the main actor.
// - Cancel-and-replace comes from `SingleFlightRefreshing`. This type writes
//   only `performRefresh()`, and checks `Task.isCancelled` after the await
//   so a superseded task never overwrites a newer result. Fetch into a
//   local, guard, then assign.
// - A preference the view edits is `private(set)` with a setter intent that
//   is a no-op for an unchanged value, so a view that mirrors it into
//   `@State` and writes back from `.onChange(of:)` cannot loop
//   (Presentation/PropertyWrappersTemplate.swift).
// - `start()` is idempotent; a view's `.task` can call it on every
//   appearance. `refresh()` (from the protocol) is the explicit reload.
// - Injection: concrete service through an `@Entry` key with a hoisted real
//   default (Presentation/EnvironmentKeyTemplate.swift).

import Foundation

@MainActor
@Observable
final class ExampleFeatureService: SingleFlightRefreshing {
    // MARK: - State

    enum LoadState: Equatable {
        case loading
        case error(ExampleFeatureError)
        case empty
        case loaded([ExampleFeatureItem])
    }

    var loadState: LoadState {
        switch (isLoading, error, items.isEmpty) {
        case (true, _, true):
            .loading
        case (_, let error?, true):
            .error(error)
        case (_, nil, true):
            .empty
        case (_, _, false):
            .loaded(items)
        }
    }

    // MARK: - Preferences

    private(set) var showsLikeCounts = true

    // MARK: - SingleFlightRefreshing

    var refreshTask: Task<Void, Never>?

    // MARK: - Private

    private let repository: any ExampleFeatureRepositoryProtocol

    private var items: [ExampleFeatureItem] = []
    private var isLoading = false
    private var error: ExampleFeatureError?
    private var hasStarted = false

    // MARK: - Init

    init(repository: any ExampleFeatureRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Intent

    func start() async {
        guard hasStarted == false else {
            return
        }

        hasStarted = true
        await refresh()
    }

    func setShowsLikeCounts(_ value: Bool) {
        guard value != showsLikeCounts else {
            return
        }

        showsLikeCounts = value
    }

    // MARK: - SingleFlightRefreshing

    func performRefresh() async {
        isLoading = true
        error = nil

        let fetched: [ExampleFeatureItem]
        do {
            fetched = try await repository.fetchItems()
        } catch {
            guard Task.isCancelled == false else {
                return
            }

            self.error = error
            isLoading = false
            return
        }

        guard Task.isCancelled == false else {
            return
        }

        items = fetched
        isLoading = false
    }
}
