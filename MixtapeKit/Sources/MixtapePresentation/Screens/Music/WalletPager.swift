//  WalletPager.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import MixtapeDomain

/// The wallet's page arithmetic over whatever the library service has loaded (engineering doc
/// §9.1). Pure and platform-shared: `WalletScreen` hands it `libraryService.pages[library.id]`
/// and the return-to-sleeve sequence resolves the finished album's page through the same seam, so
/// both are testable without rendering the iOS-only view.
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

    /// Never zero: an empty wallet still shows one page of empty sleeves.
    var pageCount: Int {
        WalletPosition.pageCount(albumCount: albums.count, columns: columns)
    }

    func albums(onPage page: Int) -> [MediaItem] {
        let perPage = columns * columns
        return Array(albums.dropFirst(page * perPage).prefix(perPage))
    }

    /// `nil` when the album is not among the loaded albums — including when it exists in the
    /// library but pagination has not reached it yet.
    func page(of albumID: String) -> Int? {
        WalletPosition(albumID: albumID, in: albums.map(\.id), columns: columns)?.page
    }
}
