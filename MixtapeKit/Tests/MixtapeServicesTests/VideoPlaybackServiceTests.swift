//  VideoPlaybackServiceTests.swift
//  MixtapeServicesTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeInfrastructure
@testable import MixtapeServices
import MixtapeUseCase
import Testing

@Suite(.tags(.service))
@MainActor
struct VideoPlaybackServiceTests {
    private let movie = MockLibraryRepository.sampleMovies[0]
    private let controller = StubVideoPlayerController()

    private func makeService(
        repository: MockPlaybackRepository = MockPlaybackRepository(),
        sessionService: SessionService = MockSessionService.signedIn(),
        libraryService: LibraryService? = nil,
        clock: any Clock<Duration> = ContinuousClock(),
        controllerFor: @escaping (PlaybackMethod) -> (any VideoPlayerControlling)?,
    ) -> VideoPlaybackService {
        VideoPlaybackService(
            resolveVideo: ResolveVideoPlaybackUseCase(repository: repository),
            reportStart: ReportPlaybackStartUseCase(repository: repository),
            reportProgress: ReportPlaybackProgressUseCase(repository: repository),
            reportStopped: ReportPlaybackStoppedUseCase(repository: repository),
            sessionService: sessionService,
            makeController: controllerFor,
            libraryService: libraryService,
            clock: clock,
        )
    }

    @Test func `play resolves loads plays and reports the start once`() async {
        let recorder = Recorder()
        let repository = MockPlaybackRepository(reportStartResult: { report, _ in
            recorder.append("\(report.itemID) \(report.playMethod) paused=\(report.isPaused) pos=\(report.position.components.seconds)")
        })
        let service = makeService(repository: repository) { _ in controller }
        await service.play(item: movie, startAt: .seconds(12))
        #expect(service.status == .playing)
        #expect(service.plan?.method == .directAVPlayer)
        #expect(service.item == movie)
        #expect(service.position == .seconds(12))
        #expect(service.duration == Duration(ticks: 207_797_330))
        #expect(controller.calls == ["load headers=0", "play"])
        #expect(controller.loadedStart == .seconds(12))
        #expect(controller.loadedURL?.path() == "/Videos/movie-1/stream")
        #expect(recorder.urls == ["movie-1 directPlay paused=false pos=12"])
    }

    @Test func `toggle pauses and resumes`() async {
        let service = makeService { _ in controller }
        await service.play(item: movie, startAt: .zero)
        service.togglePlayPause()
        #expect(service.status == .paused)
        service.togglePlayPause()
        #expect(service.status == .playing)
        #expect(controller.calls == ["load headers=0", "play", "pause", "play"])
    }

    @Test func `seek forwards to the controller and updates position`() async {
        let service = makeService { _ in controller }
        await service.play(item: movie, startAt: .zero)
        service.seek(to: .seconds(9))
        #expect(service.position == .seconds(9))
        #expect(controller.calls.last == "seek 9")
        controller.onPositionChange?(.seconds(10))
        #expect(service.position == .seconds(10))
    }

    @Test func `stop tears down and returns to idle`() async {
        let service = makeService { _ in controller }
        await service.play(item: movie, startAt: .zero)
        await service.stop()
        #expect(service.status == .idle)
        #expect(service.plan == nil)
        #expect(service.item == nil)
        #expect(service.isActive == false)
        #expect(controller.calls.last == "teardown")
    }

    @Test func `a player failure lands in failed`() async {
        let service = makeService { _ in controller }
        await service.play(item: movie, startAt: .zero)
        controller.onFailure?(.transport("boom"))
        #expect(service.status == .failed(.transport("boom")))
    }

    @Test func `a method with no controller is no playable source`() async {
        let repository = MockPlaybackRepository(resolveVideoResult: { _, _, _ in
            VideoSourceResolution(playSessionID: "p", sources: [
                MediaSourceCandidate(id: "s", container: "mkv", videoCodec: "hevc", audioCodec: "dts", supportsDirectPlay: true, supportsDirectStream: true, transcodingUrl: nil, runTimeTicks: nil),
            ])
        })
        let service = makeService(repository: repository) { method in method == .directVLC ? nil : controller }
        await service.play(item: movie, startAt: .zero)
        #expect(service.status == .failed(.noPlayableSource))
        #expect(service.plan?.method == .directVLC)
        #expect(controller.calls.isEmpty)
    }

    @Test func `resolution failure lands in failed and expiry signs out`() async {
        let sessionService = MockSessionService.signedIn()
        let repository = MockPlaybackRepository(resolveVideoResult: { _, _, _ in throw MixtapeError.sessionExpired })
        let service = makeService(repository: repository, sessionService: sessionService) { _ in controller }
        await service.play(item: movie, startAt: .zero)
        #expect(service.status == .failed(.sessionExpired))
        #expect(sessionService.state == .signedOut)

        let unreachable = makeService(repository: MockPlaybackRepository(resolveVideoResult: { _, _, _ in throw MixtapeError.serverUnreachable })) { _ in controller }
        await unreachable.play(item: movie, startAt: .zero)
        #expect(unreachable.status == .failed(.serverUnreachable))
    }

    // MARK: Slice 020 — session-owned teardown

    @Test func `session expiry stops video synchronously and tears down the controller`() async {
        let sessionService = MockSessionService.signedIn()
        let service = makeService(sessionService: sessionService) { _ in controller }
        sessionService.onSessionEnded = { session in service.endSession(session) }
        await service.play(item: movie, startAt: .zero)
        #expect(service.status == .playing)
        sessionService.handleSessionExpiry()
        #expect(service.status == .idle)
        #expect(service.item == nil)
        #expect(service.plan == nil)
        #expect(controller.calls.last == "teardown")
    }

    @Test func `end of playback stops`() async {
        let service = makeService { _ in controller }
        await service.play(item: movie, startAt: .zero)
        controller.onEnded?()
        await Task.yield()
        for _ in 0 ..< 10 where service.status != .idle {
            await Task.yield()
        }
        #expect(service.status == .idle)
    }

    @Test func `a directVLC plan selects the VLC controller and still reports the start once`() async {
        let recorder = Recorder()
        let avPlayer = StubVideoPlayerController()
        let vlc = StubVideoPlayerController()
        let repository = MockPlaybackRepository(
            resolveVideoResult: { _, _, _ in
                VideoSourceResolution(playSessionID: "psid", sources: [
                    MediaSourceCandidate(id: "s", container: "mkv", videoCodec: "h264", audioCodec: "aac", supportsDirectPlay: true, supportsDirectStream: true, transcodingUrl: nil, runTimeTicks: 484_050_000),
                ])
            },
            reportStartResult: { report, _ in recorder.append("\(report.playMethod)") },
        )
        let service = makeService(repository: repository) { method in method == .directVLC ? vlc : avPlayer }
        await service.play(item: movie, startAt: .zero)
        #expect(service.plan?.method == .directVLC)
        #expect(service.status == .playing)
        #expect(vlc.calls == ["load headers=0", "play"])
        #expect(avPlayer.calls.isEmpty)
        #expect(recorder.urls == ["directPlay"])
    }

    // MARK: Reporting cadence (slice 008)

    /// Awaits the detached report tasks a synchronous control method fires.
    private func settle() async {
        for _ in 0 ..< 20 {
            await Task.yield()
        }
    }

    @Test func `discrete events each report exactly once`() async {
        let reports = ReportLog()
        let repository = Self.loggingRepository(reports)
        let service = makeService(repository: repository) { _ in controller }
        await service.play(item: movie, startAt: .zero) // start
        await settle()
        service.togglePlayPause() // pause -> progress paused
        await settle()
        service.togglePlayPause() // resume -> progress not paused
        await settle()
        service.seek(to: .seconds(5)) // seek -> progress
        await settle()
        await service.stop() // stopped
        #expect(reports.entries == [
            "start pos=0 paused=false",
            "progress pos=0 paused=true",
            "progress pos=0 paused=false",
            "progress pos=5 paused=false",
            "stopped pos=5 paused=false",
        ])
    }

    @Test func `progress fires once per interval while playing`() async {
        let reports = ReportLog()
        let clock = ManualClock()
        let service = makeService(repository: Self.loggingRepository(reports), clock: clock) { _ in controller }
        await service.play(item: movie, startAt: .zero)
        await clock.tick() // 10 s
        #expect(await eventually { reports.entries.count == 2 })
        await clock.tick() // 20 s
        #expect(await eventually { reports.entries.count == 3 })
        await service.stop()
        #expect(reports.entries == [
            "start pos=0 paused=false",
            "progress pos=0 paused=false",
            "progress pos=0 paused=false",
            "stopped pos=0 paused=false",
        ])
    }

    // MARK: Pause, resume and seek arrive from the player (slice 014, Triage 11)

    @Test func `a pause from the player moves the service to paused and sends exactly one pause report`() async {
        let reports = ReportLog()
        let service = makeService(repository: Self.loggingRepository(reports)) { _ in controller }
        await service.play(item: movie, startAt: .zero)
        controller.onPositionChange?(.seconds(4))
        controller.onTransportEvent?(.paused) // AVKit's pause button, or the VLC overlay's
        await settle()
        #expect(service.status == .paused)
        #expect(reports.entries == ["start pos=0 paused=false", "progress pos=4 paused=true"])
        controller.onTransportEvent?(.paused) // the player announcing a state it is already in
        await settle()
        #expect(reports.entries.count == 2)
    }

    @Test func `the heartbeat sends nothing while paused and resumes with exactly one resume report`() async {
        let reports = ReportLog()
        let clock = ManualClock()
        let service = makeService(repository: Self.loggingRepository(reports), clock: clock) { _ in controller }
        await service.play(item: movie, startAt: .zero)
        controller.onTransportEvent?(.paused)
        #expect(await eventually { reports.entries.count == 2 })
        await clock.tick() // 10 s into the pause
        await clock.tick() // 20 s
        #expect(await eventually { clock.sleeperCount == 1 }) // the loop is back asleep, having sent nothing
        #expect(reports.entries == ["start pos=0 paused=false", "progress pos=0 paused=true"])
        controller.onTransportEvent?(.resumed)
        #expect(await eventually { reports.entries.count == 3 })
        #expect(service.status == .playing)
        await clock.tick() // the heartbeat is back
        #expect(await eventually { reports.entries.count == 4 })
        await service.stop()
        #expect(reports.entries == [
            "start pos=0 paused=false",
            "progress pos=0 paused=true",
            "progress pos=0 paused=false",
            "progress pos=0 paused=false",
            "stopped pos=0 paused=false",
        ])
    }

    @Test func `a seek completion reports the landed position once, paused or not`() async {
        let reports = ReportLog()
        let service = makeService(repository: Self.loggingRepository(reports)) { _ in controller }
        await service.play(item: movie, startAt: .zero)
        controller.onTransportEvent?(.seeked(.seconds(7))) // the system scrubber
        await settle()
        #expect(service.position == .seconds(7))
        controller.onTransportEvent?(.paused)
        await settle()
        controller.onTransportEvent?(.seeked(.seconds(9)))
        await settle()
        #expect(reports.entries == [
            "start pos=0 paused=false",
            "progress pos=7 paused=false",
            "progress pos=7 paused=true",
            "progress pos=9 paused=true",
        ])
    }

    @Test func `transport events before playback starts or after it stops are ignored`() async {
        let reports = ReportLog()
        let service = makeService(repository: Self.loggingRepository(reports)) { _ in controller }
        controller.onTransportEvent?(.paused)
        controller.onTransportEvent?(.seeked(.seconds(3)))
        #expect(service.status == .idle)
        #expect(service.position == .zero)
        await service.play(item: movie, startAt: .zero)
        await service.stop()
        controller.onTransportEvent?(.resumed)
        await settle()
        #expect(service.status == .idle)
        #expect(reports.entries == ["start pos=0 paused=false", "stopped pos=0 paused=false"])
    }

    @Test(arguments: [
        (Duration.seconds(43.5), false), // 89.9% of 48.4 s
        (Duration.seconds(43.56), true), // 90.0%
        (Duration.seconds(43.6), true), // 90.1%
    ])
    func `watched at stop reports the full duration at or past ninety percent`(position: Duration, watched: Bool) async {
        let reports = ReportLog()
        let repository = MockPlaybackRepository(
            resolveVideoResult: { _, _, _ in
                VideoSourceResolution(playSessionID: "psid", sources: [
                    MediaSourceCandidate(id: "s", container: "mkv", videoCodec: "h264", audioCodec: "aac", supportsDirectPlay: true, supportsDirectStream: true, transcodingUrl: nil, runTimeTicks: 484_000_000),
                ])
            },
            reportStoppedResult: { report, _ in reports.append("stopped pos=\(report.position.components.seconds)") },
        )
        let f1 = Self.f1(runtime: .seconds(48.4))
        let service = makeService(repository: repository) { _ in controller }
        await service.play(item: f1, startAt: .zero)
        controller.onPositionChange?(position)
        #expect(service.reachesWatchedThreshold == watched)
        await service.stop()
        // Watched -> reports the full 48 s so Jellyfin marks it played; not watched -> the resume point.
        let expected = watched ? "stopped pos=48" : "stopped pos=\(position.components.seconds)"
        #expect(reports.entries.contains(expected))
    }

    private nonisolated static func line(_ kind: String, _ r: PlaybackReport) -> String {
        "\(kind) pos=\(r.position.components.seconds) paused=\(r.isPaused)"
    }

    private static func loggingRepository(_ log: ReportLog) -> MockPlaybackRepository {
        MockPlaybackRepository(
            reportStartResult: { r, _ in log.append(line("start", r)) },
            reportProgressResult: { r, _ in log.append(line("progress", r)) },
            reportStoppedResult: { r, _ in log.append(line("stopped", r)) },
        )
    }

    private static func f1(runtime: Duration) -> MediaItem {
        MediaItem(
            id: "f1", name: "F1", kind: .movie, overview: nil, productionYear: 2025, runtime: runtime, indexNumber: nil, parentIndexNumber: nil,
            seriesName: nil, albumArtist: nil, primaryImageTag: nil, backdropImageTag: nil, parentPrimaryImageTag: nil,
            playback: PlaybackState(position: .zero, isWatched: false),
        )
    }
}
