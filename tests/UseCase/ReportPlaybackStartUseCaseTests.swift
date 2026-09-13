//  ReportPlaybackStartUseCaseTests.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

@testable import Mixtape
import Testing

@Suite(.tags(.useCase))
struct ReportPlaybackStartUseCaseTests {
    private let session = MockAuthRepository.sampleSession
    private let report = PlaybackReport(
        itemID: "item-1", mediaSourceID: "src", playSessionID: "psid", position: .seconds(5), isPaused: false, playMethod: .directPlay,
    )

    @Test func `the report reaches the repository`() async {
        let recorder = Recorder()
        let repository = MockPlaybackRepository(reportStartResult: { report, _ in recorder.append("\(report.itemID) \(report.playMethod)") })
        await ReportPlaybackStartUseCase(repository: repository)(report, session: session)
        #expect(recorder.urls == ["item-1 directPlay"])
    }

    @Test func `a repository failure is swallowed`() async {
        let repository = MockPlaybackRepository(reportStartResult: { _, _ in throw MixtapeError.transport("503") })
        await ReportPlaybackStartUseCase(repository: repository)(report, session: session)
    }
}
