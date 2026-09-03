//  ReportPlaybackStartUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

/// `POST /Sessions/Playing`, once per play. Failures never surface as playback errors (§8): the
/// repository logs them and this swallows them.
public nonisolated struct ReportPlaybackStartUseCase: Sendable {
    private let repository: any PlaybackRepositoryProtocol

    public init(repository: any PlaybackRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(_ report: PlaybackReport, session: UserSession) async {
        try? await repository.reportStart(report, session: session)
    }
}
