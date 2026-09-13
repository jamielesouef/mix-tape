//  WalletPager.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import MixtapeDomain

nonisolated struct WalletPager: Equatable {
    let albums: [MediaItem]
    let columns: Int

    init(state: LoadState<Page<MediaItem>>?, columns: Int) {
        if case let .loaded(page) = state {
            albums = page.items
        } else {
            albums = []
        }
        self.columns = columns
    }

    var pageCount: Int {
        WalletPosition.pageCount(albumCount: albums.count, columns: columns)
    }

    func albums(onPage page: Int) -> [MediaItem] {
        let perPage = columns * columns
        return Array(albums.dropFirst(page * perPage).prefix(perPage))
    }

    func page(of albumID: String) -> Int? {
        WalletPosition(albumID: albumID, in: albums.map(\.id), columns: columns)?.page
    }
}
