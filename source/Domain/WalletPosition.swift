//  WalletPosition.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

nonisolated struct WalletPosition: Sendable, Hashable {
    let page: Int
    let slot: Int

    init(page: Int, slot: Int) {
        self.page = page
        self.slot = slot
    }

    init?(albumID: String, in albumIDs: [String], columns: Int) {
        guard columns > 0, let index = albumIDs.firstIndex(of: albumID) else { return nil }
        let perPage = columns * columns
        self.init(page: index / perPage, slot: index % perPage)
    }

    static func pageCount(albumCount: Int, columns: Int) -> Int {
        guard columns > 0 else { return 1 }
        let perPage = columns * columns
        return max(1, (albumCount + perPage - 1) / perPage)
    }
}
