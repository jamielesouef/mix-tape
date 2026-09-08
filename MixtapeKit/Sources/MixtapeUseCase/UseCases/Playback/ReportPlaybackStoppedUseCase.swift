//  ReportPlaybackStoppedUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

/// `POST /Sessions/Playing/Stopped`, closing the session 006's start report opened. Failures are
/// swallowed (§8).
public nonisolated struct ReportPlaybackStoppedUseCase: Sendable {
    private let repository: any PlaybackRepositoryProtocol

    public init(repository: any PlaybackRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(_ report: PlaybackReport, session: UserSession) async {
        try? await repository.reportStopped(report, session: session)
    }
}
