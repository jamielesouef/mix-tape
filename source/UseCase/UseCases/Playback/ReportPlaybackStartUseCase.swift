//  ReportPlaybackStartUseCase.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct ReportPlaybackStartUseCase: Sendable {
    private let repository: any PlaybackRepositoryProtocol

    public init(repository: any PlaybackRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(_ report: PlaybackReport, session: UserSession) async {
        try? await repository.reportStart(report, session: session)
    }
}
