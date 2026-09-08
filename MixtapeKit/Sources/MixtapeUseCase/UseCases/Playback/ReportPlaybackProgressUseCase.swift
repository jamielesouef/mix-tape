//  ReportPlaybackProgressUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

/// `POST /Sessions/Playing/Progress`. A dropped heartbeat never becomes a playback error (§8),
/// so failures are swallowed here.
public nonisolated struct ReportPlaybackProgressUseCase: Sendable {
    private let repository: any PlaybackRepositoryProtocol

    public init(repository: any PlaybackRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(_ report: PlaybackReport, session: UserSession) async {
        try? await repository.reportProgress(report, session: session)
    }
}
