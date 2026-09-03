//  ResolveVideoPlaybackUseCase.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain

/// Item + start position → `PlaybackPlan` (engineering doc §8 "Choosing the method"). The first
/// source wins; a direct-play or direct-stream source gets a client-built stream URL carrying
/// `ApiKey` (decision 42) and `deviceId` (decision 26); a transcode passes the server's
/// `TranscodingUrl` through verbatim (decision 7 carve-out).
public nonisolated struct ResolveVideoPlaybackUseCase: Sendable {
    private let repository: any PlaybackRepositoryProtocol

    public init(repository: any PlaybackRepositoryProtocol) {
        self.repository = repository
    }

    public func callAsFunction(itemID: String, startAt: Duration, session: UserSession) async throws -> PlaybackPlan {
        let resolution = try await repository.resolveVideo(itemID: itemID, startAt: startAt, session: session)
        guard let source = resolution.sources.first else { throw MixtapeError.noPlayableSource }

        let method: PlaybackMethod
        let playMethod: PlayMethod
        let streamURL: URL
        if source.supportsDirectPlay || source.supportsDirectStream {
            streamURL = try Self.streamURL(itemID: itemID, source: source, playSessionID: resolution.playSessionID, session: session)
            method = isAVPlayerNative(container: source.container, videoCodec: source.videoCodec, audioCodec: source.audioCodec) ? .directAVPlayer : .directVLC
            playMethod = source.supportsDirectPlay ? .directPlay : .directStream
        } else if let path = source.transcodingUrl, let url = URL(string: path, relativeTo: session.serverURL)?.absoluteURL {
            streamURL = url
            method = .transcodeHLS
            playMethod = .transcode
        } else {
            throw MixtapeError.noPlayableSource
        }

        return PlaybackPlan(
            itemID: itemID,
            mediaSourceID: source.id,
            playSessionID: resolution.playSessionID,
            method: method,
            playMethod: playMethod,
            streamURL: streamURL,
            startPosition: startAt,
            totalDuration: source.runTimeTicks.map { Duration(ticks: $0) },
        )
    }

    private static func streamURL(itemID: String, source: MediaSourceCandidate, playSessionID: String, session: UserSession) throws -> URL {
        var components = URLComponents(url: session.serverURL.appending(path: "/Videos/\(itemID)/stream"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "static", value: "true"),
            URLQueryItem(name: "mediaSourceId", value: source.id),
            URLQueryItem(name: "playSessionId", value: playSessionID),
            URLQueryItem(name: "deviceId", value: session.deviceID),
            URLQueryItem(name: "ApiKey", value: session.accessToken),
        ]
        guard let url = components?.url else { throw MixtapeError.noPlayableSource }
        return url
    }
}
