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

/// Mints and records a distinct `StubVideoPlayerController` per `makeController` call, so a test
/// can tell an operation's own controller apart from the one that replaced it.
@MainActor
private final class ControllerSpy {
    private(set) var instances: [StubVideoPlayerController] = []

    func make(for _: PlaybackMethod) -> any VideoPlayerControlling {
        let controller = StubVideoPlayerController()
        instances.append(controller)
        return controller
    }
}

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

    // MARK: Slice 021 — operation generations

    @Test func `AC21a a stale resolution for a replaced item never overwrites the newer item`() async {
        let gate = Gate()
        gate.close()
        let movieA = movie
        let movieB = MockLibraryRepository.sampleMovies[1]
        let controller = StubVideoPlayerController()
        let repository = MockPlaybackRepository(resolveVideoResult: { itemID, _, _ in
            if itemID == movieA.id {
                await gate.wait()
            }
            return MockPlaybackRepository.sampleResolution
        })
        let service = makeService(repository: repository) { _ in controller }
        let stale = Task { await service.play(item: movieA, startAt: .zero) }
        await Task.yield()
        await service.play(item: movieB, startAt: .zero)
        #expect(service.item == movieB)
        #expect(service.plan?.itemID == movieB.id)
        #expect(service.status == .playing)
        let callsAfterB = controller.calls
        gate.open()
        await stale.value
        #expect(controller.calls == callsAfterB) // A's late resolution installed nothing
        #expect(service.item == movieB)
        #expect(service.plan?.itemID == movieB.id)
        #expect(service.status == .playing)
    }

    /// Reviewer finding on AC21a/AC21b/AC21h: those three gate `resolveVideo`, so the stale
    /// operation always returns at the resolution guard (`VideoPlaybackService.swift:105`) and
    /// never reaches installing a controller — the four callback guards at lines 113-128 are
    /// exercised by nothing. This mints a distinct stub per `play()` call so A's controller is
    /// actually installed and live, then fires its callbacks directly after B has replaced it.
    @Test func `AC21a a stale controller's already-installed callbacks after a newer play never touch the newer state`() async {
        let spy = ControllerSpy()
        let service = makeService { method in spy.make(for: method) }
        await service.play(item: movie, startAt: .zero) // A installs its own controller and callbacks
        let staleController = spy.instances[0]
        let movieB = MockLibraryRepository.sampleMovies[1]
        await service.play(item: movieB, startAt: .seconds(3)) // B replaces A's generation
        #expect(spy.instances.count == 2)
        #expect(service.item == movieB)
        #expect(service.position == .seconds(3))
        #expect(service.status == .playing)

        staleController.onPositionChange?(.seconds(99))
        staleController.onTransportEvent?(.paused)
        staleController.onEnded?()
        staleController.onFailure?(.transport("stale"))

        #expect(service.item == movieB)
        #expect(service.position == .seconds(3))
        #expect(service.status == .playing)
    }

    @Test func `AC21b a stale resolution for the same item never overwrites the later play of it`() async {
        let gate = Gate()
        gate.close()
        let calls = Counter()
        let controller = StubVideoPlayerController()
        let repository = MockPlaybackRepository(resolveVideoResult: { _, _, _ in
            if calls.next() == 0 {
                await gate.wait()
            }
            return MockPlaybackRepository.sampleResolution
        })
        let service = makeService(repository: repository) { _ in controller }
        let stale = Task { await service.play(item: movie, startAt: .zero) }
        await Task.yield()
        await service.play(item: movie, startAt: .seconds(5))
        #expect(service.status == .playing)
        #expect(service.position == .seconds(5))
        let callsAfterSecond = controller.calls
        gate.open()
        await stale.value
        // The item-ID-only guard this replaces would have let the first (stale) play's completion
        // pass `self.item?.id == item.id` and overwrite the second's plan/controller.
        #expect(controller.calls == callsAfterSecond)
        #expect(service.status == .playing)
        #expect(service.position == .seconds(5))
    }

    @Test(arguments: [false, true])
    func `AC21h a stale resolution after stop cannot resurrect playback, success or failure`(shouldThrow: Bool) async {
        let gate = Gate()
        gate.close()
        let controller = StubVideoPlayerController()
        let repository = MockPlaybackRepository(resolveVideoResult: { _, _, _ in
            await gate.wait()
            if shouldThrow {
                throw MixtapeError.serverUnreachable
            }
            return MockPlaybackRepository.sampleResolution
        })
        let service = makeService(repository: repository) { _ in controller }
        let held = Task { await service.play(item: movie, startAt: .zero) }
        await Task.yield()
        #expect(service.status == .preparing)
        await service.stop()
        #expect(service.status == .idle)
        #expect(service.item == nil)
        gate.open()
        await held.value
        #expect(service.status == .idle)
        #expect(service.item == nil)
        #expect(controller.calls.isEmpty) // no controller ever installed by the stale completion
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

    /// Triage 25 (slice 021 AC21f): awaits the report landing directly via `ReportLog.waitForCount`,
    /// resumed by `append` itself, instead of polling with `eventually` — no timing window to lose.
    @Test func `progress fires once per interval while playing`() async {
        let reports = ReportLog()
        let clock = ManualClock()
        let service = makeService(repository: Self.loggingRepository(reports), clock: clock) { _ in controller }
        await service.play(item: movie, startAt: .zero)
        #expect(reports.entries == ["start pos=0 paused=false"])
        await clock.tick() // 10 s
        await reports.waitForCount(2)
        await clock.tick() // 20 s
        await reports.waitForCount(3)
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
