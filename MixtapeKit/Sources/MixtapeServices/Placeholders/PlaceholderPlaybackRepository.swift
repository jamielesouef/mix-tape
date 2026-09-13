//  PlaceholderPlaybackRepository.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeUseCase

nonisolated struct PlaceholderPlaybackRepository: PlaybackRepositoryProtocol {
    func resolveVideo(itemID _: String, startAt _: Duration, session _: UserSession) async throws -> VideoSourceResolution {
        throw MixtapeError.serverUnreachable
    }

    func audioStream(track: MediaItem, session: UserSession, playSessionID _: String) -> AudioStream {
        AudioStream(url: session.serverURL.appending(path: "Audio/\(track.id)/unavailable"), playMethod: .directPlay)
    }

    func reportStart(_: PlaybackReport, session _: UserSession) async throws {
        throw MixtapeError.serverUnreachable
    }

    func reportProgress(_: PlaybackReport, session _: UserSession) async throws {
        throw MixtapeError.serverUnreachable
    }

    func reportStopped(_: PlaybackReport, session _: UserSession) async throws {
        throw MixtapeError.serverUnreachable
    }
}
