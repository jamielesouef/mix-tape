//  BuildAudioStreamURLUseCaseTests.swift
//  MixtapeUseCaseTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
@testable import MixtapeUseCase
import Testing

@Suite(.tags(.useCase))
struct BuildAudioStreamURLUseCaseTests {
    private let session = MockAuthRepository.sampleSession

    private func track(container: String?) -> MediaItem {
        MediaItem(
            id: "track-1", name: "Song", kind: .audio, overview: nil, productionYear: nil, runtime: .seconds(200), indexNumber: 1, parentIndexNumber: 1,
            seriesName: nil, albumArtist: "Artist", primaryImageTag: nil, backdropImageTag: nil, parentPrimaryImageTag: "a1", albumID: "album-1", container: container,
            playback: PlaybackState(position: .zero, isWatched: false),
        )
    }

    @Test func `a flac track direct-plays and the mock builder is used`() {
        let stream = BuildAudioStreamURLUseCase(repository: MockPlaybackRepository())(track: track(container: "flac"), session: session)
        #expect(stream.playMethod == .directPlay)
    }

    @Test func `an exotic container transcodes`() {
        let stream = BuildAudioStreamURLUseCase(repository: MockPlaybackRepository())(track: track(container: "opus"), session: session)
        #expect(stream.playMethod == .transcode)
    }
}
