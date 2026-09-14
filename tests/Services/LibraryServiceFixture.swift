//  LibraryServiceFixture.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 13/09/2026.
//

import Foundation
@testable import Mixtape

/// Shared setup for the LibraryService suites, which are split across files by topic.
@MainActor
enum LibraryServiceFixture {
    static func makeService(
        repository: MockLibraryRepository = MockLibraryRepository(),
        sessionService: SessionService = MockSessionService.signedIn()
    ) -> LibraryService {
        MockLibraryService.make(repository: repository, sessionService: sessionService)
    }

    static func pagingRepository(
        pageSizes: [Int],
        total: Int,
        recorder: Recorder
    ) -> MockLibraryRepository {
        let calls = Counter()
        return MockLibraryRepository(itemsResult: { _, _, page, _ in
            let call = calls.next()
            recorder.append("\(page.startIndex)/\(page.limit)")
            let count = call < pageSizes.count ? pageSizes[call] : 0
            let items = (0 ..< count).map { offset in Self.album("m\(page.startIndex + offset)") }
            return Page(items: items, totalCount: total, startIndex: page.startIndex)
        })
    }

    nonisolated static func album(_ id: String) -> MediaItem {
        MediaItem(
            id: id,
            name: id,
            kind: .musicAlbum,
            overview: nil,
            productionYear: nil,
            runtime: nil,
            indexNumber: nil,
            parentIndexNumber: nil,
            albumArtist: nil,
            primaryImageTag: nil,
            backdropImageTag: nil,
            parentPrimaryImageTag: nil,
            playback: PlaybackState(position: .zero)
        )
    }
}
