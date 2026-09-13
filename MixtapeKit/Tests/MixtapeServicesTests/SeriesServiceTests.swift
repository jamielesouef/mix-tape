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

    // MARK: Slice 023 — refresh invalidation, season/episode coalescing

    @Test func `refresh while loadSeasons is in flight does not let the stale response repopulate the cleared cache`() async {
        let gate = Gate()
        gate.close()
        let started = Recorder()
        let repository = MockLibraryRepository(seasonsResult: { id, _ in
            started.append(id)
            await gate.wait()
            return MockLibraryRepository.sampleSeasons
        })
        let service = MockSeriesService.make(repository: repository)
        let load = Task { await service.loadSeasons(seriesID: "series-1") }
        #expect(await eventually { started.urls == ["series-1"] })
        service.refresh()
        gate.open()
        await load.value
        #expect(service.seasons["series-1"] == nil)
    }

    @Test func `concurrent loadSeasons requests for the same series fire one network call`() async {
        let recorder = Recorder()
        let gate = Gate()
        gate.close()
        let repository = MockLibraryRepository(seasonsResult: { id, _ in
            recorder.append(id)
            await gate.wait()
            return MockLibraryRepository.sampleSeasons
        })
        let service = MockSeriesService.make(repository: repository)
        let first = Task { await service.loadSeasons(seriesID: "series-1") }
        await Task.yield()
        await service.loadSeasons(seriesID: "series-1")
        gate.open()
        await first.value
        #expect(recorder.urls == ["series-1"])
    }

    @Test func `concurrent loadEpisodes requests for the same season fire one network call`() async {
        let recorder = Recorder()
        let gate = Gate()
        gate.close()
        let repository = MockLibraryRepository(episodesResult: { series, season, _ in
            recorder.append("\(series)/\(season)")
            await gate.wait()
            return MockLibraryRepository.sampleEpisodes
        })
        let service = MockSeriesService.make(repository: repository)
        let first = Task { await service.loadEpisodes(seriesID: "series-1", seasonID: "season-1") }
        await Task.yield()
        await service.loadEpisodes(seriesID: "series-1", seasonID: "season-1")
        gate.open()
        await first.value
        #expect(recorder.urls == ["series-1/season-1"])
    }

    @Test func `failure lands in failed and expiry signs out`() async {
        let sessionService = MockSessionService.signedIn()
        let repository = MockLibraryRepository(
            seasonsResult: { _, _ in throw MixtapeError.serverUnreachable },
            episodesResult: { _, _, _ in throw MixtapeError.sessionExpired },
        )
        let service = MockSeriesService.make(repository: repository, sessionService: sessionService)
        sessionService.onSessionEnded = { _ in service.endSession() }
        await service.loadSeasons(seriesID: "series-1")
        #expect(service.seasons["series-1"] == .failed(.serverUnreachable))
        await service.loadEpisodes(seriesID: "series-1", seasonID: "season-1")
        #expect(service.episodes["season-1"] == nil)
        #expect(sessionService.state == .signedOut)
    }
}
