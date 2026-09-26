// TEMPLATE — Service unit test. Copy, rename, delete this header.
//
// Layer: <TestTarget>/Services/<Name>ServiceTests.swift
// Pair with: StubRepositoryTemplate.swift
//
// - The service is `@MainActor`. Construct it with `await`, call its
//   `async` entry points with `await`, read its state with
//   `await sut.loadState`. Never `@MainActor` on the `@Test`.
// - No polling. `start()` and `refresh()` are awaited, so the state is
//   settled when they return. The one in-flight test uses the stub's gate
//   and `waitUntilFetchCount`, both continuation-backed.
// - Assert the DERIVED `loadState`. `LoadState` is `Equatable`, so
//   `#expect(state == .empty)` reads as the sentence it is. Asserting
//   `.empty` from `[]` and `.error` from a failure tests the derivation, not
//   the stub.
// - Cover: initial state, happy path, empty, failure, idempotent `start`,
//   `refresh` re-fetches, and a superseded refresh never overwrites the
//   newer result.

import Testing
@testable import ExampleApp

@Suite("ExampleFeatureService", .tags(.service))
struct ExampleFeatureServiceTests {
    // MARK: - Fixtures

    private static func item(_ id: String) -> ExampleFeatureItem {
        ExampleFeatureItem(id: id, title: "Title \(id)", thumbnailURL: nil, likeCount: 0, ownerID: 1)
    }

    // MARK: - Tests

    @Test("the load state is empty before start")
    func initialState() async {
        let sut = await ExampleFeatureService(repository: StubExampleFeatureRepository())

        #expect(await sut.loadState == .empty)
    }

    @Test("start resolves the fetched items into the loaded state")
    func startLoadsItems() async {
        let items = [Self.item("a"), Self.item("b")]
        let repository = StubExampleFeatureRepository(fetchItemsResult: .success(items))
        let sut = await ExampleFeatureService(repository: repository)

        await sut.start()

        #expect(await sut.loadState == .loaded(items))
    }

    @Test("an empty feed settles into the empty state, not loading and not an error")
    func emptyFeed() async {
        let repository = StubExampleFeatureRepository(fetchItemsResult: .success([]))
        let sut = await ExampleFeatureService(repository: repository)

        await sut.start()

        #expect(await sut.loadState == .empty)
        #expect(await repository.fetchItemsCallCount == 1)
    }

    @Test("a fetch failure surfaces as the error state")
    func fetchFailure() async {
        let repository = StubExampleFeatureRepository(fetchItemsResult: .failure(.network))
        let sut = await ExampleFeatureService(repository: repository)

        await sut.start()

        #expect(await sut.loadState == .error(.network))
    }

    @Test("start is idempotent across repeated calls")
    func startOnlyFetchesOnce() async {
        let repository = StubExampleFeatureRepository(fetchItemsResult: .success([Self.item("a")]))
        let sut = await ExampleFeatureService(repository: repository)

        await sut.start()
        await sut.start()

        #expect(await repository.fetchItemsCallCount == 1)
    }

    @Test("refresh fetches again and replaces the loaded items")
    func refreshReplacesItems() async {
        let repository = StubExampleFeatureRepository(fetchItemsResult: .success([Self.item("a")]))
        let sut = await ExampleFeatureService(repository: repository)
        await sut.start()

        await repository.updateFetchItemsResult(.success([Self.item("z")]))
        await sut.refresh()

        #expect(await sut.loadState == .loaded([Self.item("z")]))
        #expect(await repository.fetchItemsCallCount == 2)
    }

    @Test("a superseded refresh never overwrites the newer result")
    func supersededRefreshDoesNotOverwrite() async {
        let repository = StubExampleFeatureRepository(fetchItemsResult: .success([Self.item("stale")]))
        let sut = await ExampleFeatureService(repository: repository)
        await repository.closeGate()

        let first = Task { await sut.refresh() }
        await repository.waitUntilFetchCount(reaches: 1)
        await repository.updateFetchItemsResult(.success([Self.item("fresh")]))
        let second = Task { await sut.refresh() }
        await repository.waitUntilFetchCount(reaches: 2)
        await repository.openGate()
        await first.value
        await second.value

        #expect(await sut.loadState == .loaded([Self.item("fresh")]))
    }
}
