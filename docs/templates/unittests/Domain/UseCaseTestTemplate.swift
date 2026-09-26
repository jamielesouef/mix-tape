// TEMPLATE — UseCase unit test. Copy, rename, delete this header.
//
// Layer: <TestTarget>/Domain/<Name>UseCaseTests.swift
//
// - A use case is a pure static function: no async work, no stub. The test
//   declares no effects because its body has none; the formatter strips an
//   unused `async` or `throws`.
// - Closely related inputs checking the SAME behaviour go in one
//   parameterised `@Test(arguments:)`, one tuple per case. A DIFFERENT
//   behaviour (a boundary, an edge case) is its own `@Test` with its own
//   sentence.
// - Cover the boundary the real function's `guard` / `switch` branches on:
//   empty input, either end of the range, a stale index.

import Testing
@testable import ExampleApp

@Suite("ExampleFeatureFocusUseCase", .tags(.domain))
struct ExampleFeatureFocusUseCaseTests {
    // MARK: - nextIndex

    @Test(
        "moves one step in the requested direction while an index exists there",
        arguments: [
            (0, ExampleMoveDirection.forward, 1),
            (1, ExampleMoveDirection.forward, 2),
            (2, ExampleMoveDirection.backward, 1)
        ]
    )
    func movesOneStep(current: Int, moved: ExampleMoveDirection, expected: Int) {
        #expect(ExampleFeatureFocusUseCase.nextIndex(current: current, count: 3, moved: moved) == expected)
    }

    @Test(
        "returns nil at either end instead of an out-of-range index",
        arguments: [
            (2, ExampleMoveDirection.forward),
            (0, ExampleMoveDirection.backward)
        ]
    )
    func stopsAtTheEnds(current: Int, moved: ExampleMoveDirection) {
        #expect(ExampleFeatureFocusUseCase.nextIndex(current: current, count: 3, moved: moved) == nil)
    }

    @Test("returns nil for an empty list")
    func handlesEmptyList() {
        #expect(ExampleFeatureFocusUseCase.nextIndex(current: 0, count: 0, moved: .forward) == nil)
    }

    // MARK: - clamped

    @Test(
        "clamps a remembered index into the current list",
        arguments: [
            (5, 3, 2),
            (-1, 3, 0),
            (1, 3, 1),
            (4, 0, 0)
        ]
    )
    func clampsIntoRange(index: Int, count: Int, expected: Int) {
        #expect(ExampleFeatureFocusUseCase.clamped(index, count: count) == expected)
    }
}
