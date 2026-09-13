//  DisplayTitleTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import Mixtape
import Testing

@Suite(.tags(.domain))
struct DisplayTitleTests {
    private func item(kind: MediaKind, name: String, indexNumber: Int? = nil, parentIndexNumber: Int? = nil) -> MediaItem {
        MediaItem(
            id: "id", name: name, kind: kind, overview: nil, productionYear: nil, runtime: nil,
            indexNumber: indexNumber, parentIndexNumber: parentIndexNumber,
            albumArtist: nil, primaryImageTag: nil, backdropImageTag: nil, parentPrimaryImageTag: nil,
            playback: PlaybackState(position: .zero),
        )
    }

    @Test func `track renders number and name`() {
        #expect(item(kind: .audio, name: "Title", indexNumber: 3).displayTitle == "3. Title")
    }

    @Test func `album renders name`() {
        #expect(item(kind: .musicAlbum, name: "Title").displayTitle == "Title")
    }

    @Test func `missing index falls back to name`() {
        #expect(item(kind: .audio, name: "Loose").displayTitle == "Loose")
    }
}
