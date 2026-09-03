//  ImageServiceTests.swift
//  MixtapeServicesTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
@testable import MixtapeServices
import MixtapeUseCase
import Testing

@Suite(.tags(.service))
@MainActor
struct ImageServiceTests {
    private let service = MockImageService.make()

    @Test func `a track without its own art falls back to the album`() {
        let track = MockLibraryRepository.sampleTracks[0]
        let url = service.imageURL(for: track, kind: .primary, maxHeight: 300)
        #expect(url?.absoluteString == "mock://images/album-1/Primary?tag=a1&maxHeight=300")
    }

    @Test func `an item without a tag has no url and no image`() async {
        let movie = MockLibraryRepository.sampleMovies[0]
        #expect(service.imageURL(for: movie, kind: .backdrop, maxHeight: 300) != nil)
        let untagged = MockLibraryRepository.sampleLibraries[3]
        #expect(service.imageURL(for: untagged, maxHeight: 300) == nil)
        #expect(await service.image(for: untagged, maxHeight: 300) == nil)
    }

    @Test func `no session means no url`() {
        let signedOut = MockImageService.make(sessionService: MockSessionService.signedOut())
        #expect(signedOut.imageURL(for: MockLibraryRepository.sampleMovies[0], kind: .primary, maxHeight: 300) == nil)
    }
}
