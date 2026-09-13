//  WalletPosition.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

public nonisolated struct WalletPosition: Sendable, Hashable {
    public let page: Int
    public let slot: Int

    public init(page: Int, slot: Int) {
        self.page = page
        self.slot = slot
    }

    public init?(albumID: String, in albumIDs: [String], columns: Int) {
        guard columns > 0, let index = albumIDs.firstIndex(of: albumID) else { return nil }
        let perPage = columns * columns
        self.init(page: index / perPage, slot: index % perPage)
    }

    public static func pageCount(albumCount: Int, columns: Int) -> Int {
        guard columns > 0 else { return 1 }
        let perPage = columns * columns
        return max(1, (albumCount + perPage - 1) / perPage)
    }
}
