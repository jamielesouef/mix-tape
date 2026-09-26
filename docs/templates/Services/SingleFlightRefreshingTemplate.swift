// TEMPLATE — shared cancel-and-replace refresh. ONE per app. Copy once, delete this header.
//
// Layer: Services/SingleFlightRefreshing.swift
//
// Every service that loads data conforms to this instead of hand-rolling
// `task?.cancel(); task = Task { ... }`. One body, one place to get the
// `[weak self]` and the cancellation right.
//
// - `@MainActor` because the conformers are; `refreshTask` is main-actor
//   state.
// - `refresh()` cancels the in-flight task, starts a new one, and AWAITS it,
//   so a caller (a `.task`, a test) knows when the load has settled. No
//   fire-and-forget, so no polling in tests.
// - A conformer writes only `performRefresh()`, which must check
//   `Task.isCancelled` around every `await`. A cancelled task leaves state
//   to its successor and returns.

@MainActor
protocol SingleFlightRefreshing: AnyObject {
    var refreshTask: Task<Void, Never>? { get set }
    func performRefresh() async
}

extension SingleFlightRefreshing {
    func refresh() async {
        refreshTask?.cancel()
        let task = Task { [weak self] in
            guard let self else {
                return
            }

            await performRefresh()
        }
        refreshTask = task
        await task.value
    }
}
