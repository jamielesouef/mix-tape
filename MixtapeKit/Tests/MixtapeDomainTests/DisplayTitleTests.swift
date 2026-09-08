//  DisplayTitleTests.swift
//  MixtapeDomainTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import MixtapeDomain
import Testing

@Suite(.tags(.domain))
struct DisplayTitleTests {
    private func item(kind: MediaKind, name: String, indexNumber: Int? = nil, parentIndexNumber: Int? = nil) -> MediaItem {
        MediaItem(
            id: "id", name: name, kind: kind, overview: nil, productionYear: nil, runtime: nil,
            indexNumber: indexNumber, parentIndexNumber: parentIndexNumber, seriesName: nil,
            albumArtist: nil, primaryImageTag: nil, backdropImageTag: nil, parentPrimaryImageTag: nil,
            playback: PlaybackState(position: .zero, isWatched: false),
        )
    }

    @Test func `episode renders season and episode`() {
        #expect(item(kind: .episode, name: "Title", indexNumber: 4, parentIndexNumber: 2).displayTitle == "S2E4 · Title")
    }

    @Test func `track renders number and name`() {
        #expect(item(kind: .audio, name: "Title", indexNumber: 3).displayTitle == "3. Title")
    }

    @Test func `movie renders name`() {
        #expect(item(kind: .movie, name: "Title").displayTitle == "Title")
    }

    @Test func `missing index falls back to name`() {
        #expect(item(kind: .episode, name: "Special", indexNumber: nil, parentIndexNumber: 0).displayTitle == "Special")
        #expect(item(kind: .audio, name: "Loose").displayTitle == "Loose")
    }
}
