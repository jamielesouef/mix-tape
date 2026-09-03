//  PlaybackRepositoryProtocol.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain

/// Engineering doc §5, corrected by decision 12: `resolveVideo` returns sources, the use case
/// picks the method. The audio URL arrives in slice 009.
public nonisolated protocol PlaybackRepositoryProtocol: Sendable {
    func resolveVideo(itemID: String, startAt: Duration, session: UserSession) async throws -> VideoSourceResolution
    func reportStart(_ report: PlaybackReport, session: UserSession) async throws
    func reportProgress(_ report: PlaybackReport, session: UserSession) async throws
    func reportStopped(_ report: PlaybackReport, session: UserSession) async throws
}
