//  ReportPlaybackStoppedUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct ReportPlaybackStoppedUseCase: Sendable {
    private let repository: any PlaybackRepositoryProtocol

    init(repository: any PlaybackRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction(_ report: PlaybackReport, session: UserSession) async {
        try? await repository.reportStopped(report, session: session)
    }
}
