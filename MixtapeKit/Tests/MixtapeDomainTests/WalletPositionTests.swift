//  WalletPositionTests.swift
//  MixtapeDomainTests
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

@testable import MixtapeDomain
import Testing

@Suite(.tags(.domain))
struct WalletPositionTests {
    /// Five albums: one full 2×2 page and a partial second page holding the last album alone.
    private let albums = ["a", "b", "c", "d", "e"]

    @Test(arguments: [
        ("a", WalletPosition(page: 0, slot: 0)),
        ("d", WalletPosition(page: 0, slot: 3)),
        ("e", WalletPosition(page: 1, slot: 0)),
    ])
    func `2×2 pages hold four albums, the fifth opens a partial page`(albumID: String, expected: WalletPosition) {
        #expect(WalletPosition(albumID: albumID, in: albums, columns: 2) == expected)
    }

    @Test(arguments: [
        ("a", WalletPosition(page: 0, slot: 0)),
        ("e", WalletPosition(page: 0, slot: 4)),
        ("j", WalletPosition(page: 1, slot: 0)),
        ("k", WalletPosition(page: 1, slot: 1)),
    ])
    func `3×3 pages hold nine albums, the tenth opens a partial page`(albumID: String, expected: WalletPosition) {
        let eleven = albums + ["f", "g", "h", "i", "j", "k"]
        #expect(WalletPosition(albumID: albumID, in: eleven, columns: 3) == expected)
    }

    @Test func `an album not in the wallet has no position`() {
        #expect(WalletPosition(albumID: "zz", in: albums, columns: 2) == nil)
        #expect(WalletPosition(albumID: "a", in: [], columns: 2) == nil)
    }

    @Test(arguments: [
        (0, 2, 1), // an empty wallet still shows one page of empty sleeves
        (4, 2, 1),
        (5, 2, 2),
        (9, 3, 1),
        (10, 3, 2),
    ])
    func `page count rounds a partial page up and never drops below one`(albumCount: Int, columns: Int, pages: Int) {
        #expect(WalletPosition.pageCount(albumCount: albumCount, columns: columns) == pages)
    }
}
