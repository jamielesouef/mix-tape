//  ReportPlaybackProgressStoppedUseCaseTests.swift
//  MixtapeUseCaseTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
@testable import MixtapeUseCase
import Testing

@Suite(.tags(.useCase))
struct ReportPlaybackProgressStoppedUseCaseTests {
    private let session = MockAuthRepository.sampleSession
    private let report = PlaybackReport(
        itemID: "item-1", mediaSourceID: "src", playSessionID: "psid", position: .seconds(30), isPaused: false, method: .directVLC, playMethod: .directPlay,
    )

    @Test func `progress reaches the repository`() async {
        let recorder = Recorder()
        let repository = MockPlaybackRepository(reportProgressResult: { report, _ in recorder.append("progress \(report.position.components.seconds)") })
        await ReportPlaybackProgressUseCase(repository: repository)(report, session: session)
        #expect(recorder.urls == ["progress 30"])
    }

    @Test func `progress failure is swallowed`() async {
        let repository = MockPlaybackRepository(reportProgressResult: { _, _ in throw MixtapeError.transport("503") })
        await ReportPlaybackProgressUseCase(repository: repository)(report, session: session)
    }

    @Test func `stopped reaches the repository`() async {
        let recorder = Recorder()
        let repository = MockPlaybackRepository(reportStoppedResult: { report, _ in recorder.append("stopped \(report.itemID)") })
        await ReportPlaybackStoppedUseCase(repository: repository)(report, session: session)
        #expect(recorder.urls == ["stopped item-1"])
    }

    @Test func `stopped failure is swallowed`() async {
        let repository = MockPlaybackRepository(reportStoppedResult: { _, _ in throw MixtapeError.transport("503") })
        await ReportPlaybackStoppedUseCase(repository: repository)(report, session: session)
    }
}
