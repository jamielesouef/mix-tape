//  WalletReturnTests.swift
//  MixtapePresentationTests
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import MixtapeDomain
@testable import MixtapePresentation
import MixtapeServices
import Testing

/// What a wallet can do for a finished album (§9.1 "putting it back", slice 015): honour it on the
/// page the album sits on, or page in further and leave the event unacknowledged.
@Suite(.tags(.presentation))
@MainActor
struct WalletReturnTests {
    private func pager(_ service: LibraryService = MockLibraryService.loaded(), columns: Int = 2) -> WalletPager {
        WalletPager(state: service.pages["lib-music"], columns: columns)
    }

    @Test func `an album on the second page is honoured there`() {
        #expect(WalletReturn(finished: "album-5", pager: pager()) == .honour(page: 1))
    }

    @Test func `an album on the first page is honoured there`() {
        #expect(WalletReturn(finished: "album-2", pager: pager()) == .honour(page: 0))
    }

    @Test func `a wider wallet puts the same album on its single page`() {
        #expect(WalletReturn(finished: "album-5", pager: pager(columns: 3)) == .honour(page: 0))
    }

    @Test func `an album pagination has not reached is paged in, not discarded`() {
        #expect(WalletReturn(finished: "album-61", pager: pager()) == .pageIn)
    }

    @Test func `a wallet that has not loaded, or failed, pages in rather than acknowledging`() {
        #expect(WalletReturn(finished: "album-1", pager: pager(MockLibraryService.idle())) == .pageIn)
        #expect(WalletReturn(finished: "album-1", pager: pager(MockLibraryService.failed())) == .pageIn)
    }
}
