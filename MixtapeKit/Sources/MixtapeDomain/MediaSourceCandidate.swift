//  MediaSourceCandidate.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// One `MediaSource` from a `PlaybackInfo` response, before method selection.
/// `PlaybackRepositoryProtocol.resolveVideo` returns these; `ResolveVideoPlaybackUseCase`
/// turns them into a `PlaybackPlan` (decision 12).
nonisolated struct MediaSourceCandidate: Sendable, Equatable {
    let id: String
    let container: String
    let videoCodec: String?
    let audioCodec: String?
    let supportsDirectPlay: Bool
    let supportsDirectStream: Bool
    let transcodingUrl: String?
    let runTimeTicks: Int64?
}
