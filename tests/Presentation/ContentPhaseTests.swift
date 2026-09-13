//  ContentPhaseTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

@testable import Mixtape
import Testing

@Suite(.tags(.presentation))
struct ContentPhaseTests {
    @Test(arguments: [
        (LoadState<[Int]>?.none, ContentPhase<[Int]>.loading),
        (.idle, .loading),
        (.loading, .loading),
        (.failed(.serverUnreachable), .failed(.serverUnreachable)),
        (.loaded([]), .empty),
        (.loaded([1, 2]), .loaded([1, 2])),
    ])
    func `each load state maps to exactly one phase`(state: LoadState<[Int]>?, phase: ContentPhase<[Int]>) {
        #expect(ContentPhase(state) == phase)
    }

    @Test func `emptiness is the caller's to define for a non-collection value`() {
        let page = Page<Int>(items: [], totalCount: 0, startIndex: 0)
        #expect(ContentPhase(.loaded(page)) { $0.items.isEmpty } == .empty)
        let full = Page(items: [1], totalCount: 1, startIndex: 0)
        if case .loaded = ContentPhase(.loaded(full), isEmpty: { $0.items.isEmpty }) {} else {
            Issue.record("a page with items is loaded, not empty")
        }
    }
}
