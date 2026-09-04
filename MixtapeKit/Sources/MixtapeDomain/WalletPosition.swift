//  WalletPosition.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

/// Where an album sits in the wallet (engineering doc §9.1): pages are fixed `columns × columns`
/// blocks filled in the library's sort order, so page and slot follow from the album's index alone.
/// A pure rule with no I/O; the wallet lays out exactly what this says.
public nonisolated struct WalletPosition: Sendable, Hashable {
    public let page: Int
    public let slot: Int

    public init(page: Int, slot: Int) {
        self.page = page
        self.slot = slot
    }

    /// `nil` when the album is not in this wallet.
    public init?(albumID: String, in albumIDs: [String], columns: Int) {
        guard columns > 0, let index = albumIDs.firstIndex(of: albumID) else { return nil }
        let perPage = columns * columns
        self.init(page: index / perPage, slot: index % perPage)
    }

    /// Pages needed for `albumCount` albums. An empty wallet still shows one page of empty sleeves.
    public static func pageCount(albumCount: Int, columns: Int) -> Int {
        guard columns > 0 else { return 1 }
        let perPage = columns * columns
        return max(1, (albumCount + perPage - 1) / perPage)
    }
}
