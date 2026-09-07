//  SeriesServiceTests.swift
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
struct SeriesServiceTests {
    @Test func `seasons are fetched once per series`() async {
        let recorder = Recorder()
        let repository = MockLibraryRepository(seasonsResult: { id, _ in
            recorder.append(id)
            return MockLibraryRepository.sampleSeasons
        })
        let service = MockSeriesService.make(repository: repository)
        await service.loadSeasons(seriesID: "series-1")
        await service.loadSeasons(seriesID: "series-1")
        #expect(service.seasons["series-1"] == .loaded(MockLibraryRepository.sampleSeasons))
        #expect(recorder.urls == ["series-1"])
    }

    @Test func `episodes take both ids and refresh clears the cache`() async {
        let recorder = Recorder()
        let repository = MockLibraryRepository(episodesResult: { series, season, _ in
            recorder.append("\(series)/\(season)")
            return MockLibraryRepository.sampleEpisodes
        })
        let service = MockSeriesService.make(repository: repository)
        await service.loadEpisodes(seriesID: "series-1", seasonID: "season-1")
        await service.loadEpisodes(seriesID: "series-1", seasonID: "season-1")
        service.refresh()
        #expect(service.episodes.isEmpty)
        await service.loadEpisodes(seriesID: "series-1", seasonID: "season-1")
        #expect(recorder.urls == ["series-1/season-1", "series-1/season-1"])
    }

    @Test func `failure lands in failed and expiry signs out`() async {
        let sessionService = MockSessionService.signedIn()
        let repository = MockLibraryRepository(
            seasonsResult: { _, _ in throw MixtapeError.serverUnreachable },
            episodesResult: { _, _, _ in throw MixtapeError.sessionExpired },
        )
        let service = MockSeriesService.make(repository: repository, sessionService: sessionService)
        // Slice 020: wired the way `AppContainer` wires it, so expiry's `.failed` write (unreachable
        // by the epoch guard per decision log row 4) is observed as the `endSession()` reset instead.
        sessionService.onSessionEnded = { _ in service.endSession() }
        await service.loadSeasons(seriesID: "series-1")
        #expect(service.seasons["series-1"] == .failed(.serverUnreachable))
        await service.loadEpisodes(seriesID: "series-1", seasonID: "season-1")
        #expect(service.episodes["season-1"] == nil) // endSession() cleared it; the stale write never lands
        #expect(sessionService.state == .signedOut)
    }
}
