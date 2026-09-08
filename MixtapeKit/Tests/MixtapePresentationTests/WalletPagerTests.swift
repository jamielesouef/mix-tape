//  WalletPagerTests.swift
//  MixtapePresentationTests
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import MixtapeDomain
@testable import MixtapePresentation
import MixtapeServices
import Testing

/// Page resolution over what `LibraryService` has loaded — the seam `WalletScreen` reads and the
/// return-to-sleeve sequence resolves through. Five sample albums in the mock music library.
@Suite(.tags(.presentation))
@MainActor
struct WalletPagerTests {
    private let libraryID = "lib-music"

    private func pager(_ service: LibraryService, columns: Int) -> WalletPager {
        WalletPager(state: service.pages[libraryID], columns: columns)
    }

    @Test func `a phone wallet pages five albums as four then one`() {
        let pager = pager(MockLibraryService.loaded(), columns: 2)
        #expect(pager.pageCount == 2)
        #expect(pager.albums(onPage: 0).map(\.id) == ["album-1", "album-2", "album-3", "album-4"])
        #expect(pager.albums(onPage: 1).map(\.id) == ["album-5"])
        #expect(pager.albums(onPage: 2).isEmpty)
    }

    @Test func `a regular-width wallet fits five albums on one page`() {
        let pager = pager(MockLibraryService.loaded(), columns: 3)
        #expect(pager.pageCount == 1)
        #expect(pager.albums(onPage: 0).count == 5)
    }

    @Test func `the finished album resolves to the page it sits on`() {
        let pager = pager(MockLibraryService.loaded(), columns: 2)
        #expect(pager.page(of: "album-1") == 0)
        #expect(pager.page(of: "album-5") == 1)
    }

    @Test func `an album pagination has not reached resolves to no page`() {
        let pager = pager(MockLibraryService.loaded(), columns: 2)
        #expect(pager.page(of: "album-99") == nil)
    }

    @Test func `an empty library still shows one page of empty sleeves`() {
        let pager = pager(MockLibraryService.empty(), columns: 2)
        #expect(pager.pageCount == 1)
        #expect(pager.albums.isEmpty)
        #expect(pager.albums(onPage: 0).isEmpty)
    }

    @Test func `a library that has not loaded, or failed, has no albums and one page`() {
        for service in [MockLibraryService.idle(), MockLibraryService.loading(), MockLibraryService.failed()] {
            let pager = pager(service, columns: 2)
            #expect(pager.albums.isEmpty)
            #expect(pager.pageCount == 1)
            #expect(pager.page(of: "album-1") == nil)
        }
    }
}
