//  ReportPlaybackProgressUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct ReportPlaybackProgressUseCase: Sendable {
    private let repository: any PlaybackRepositoryProtocol

    init(repository: any PlaybackRepositoryProtocol) {
        self.repository = repository
    }

    func callAsFunction(_ report: PlaybackReport, session: UserSession) async {
        try? await repository.reportProgress(report, session: session)
    }
}
