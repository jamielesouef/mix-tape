//  JellyfinPlaybackRepository.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

nonisolated struct JellyfinPlaybackRepository: PlaybackRepositoryProtocol {
    private let client: JellyfinHTTPClient
    private let appVersion: String

    init(client: JellyfinHTTPClient, appVersion: String) {
        self.client = client
        self.appVersion = appVersion
    }

    func audioStream(track: MediaItem, session: UserSession, playSessionID: String) -> AudioStream {
        guard isNativeAudioContainer(track.container) else {
            AppLogger.playback.info("audio HLS fallback fired for track \(track.id) (container \(track.container ?? "?"))")
            return AudioStream(url: hlsFallbackURL(track: track, session: session, playSessionID: playSessionID), playMethod: .transcode)
        }
        var components = URLComponents(url: session.serverURL.appending(path: "/Audio/\(track.id)/universal"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "userId", value: session.userID),
            URLQueryItem(name: "deviceId", value: session.deviceID),
            URLQueryItem(name: "container", value: "flac,alac,m4a,mp3,aac,wav,aiff"),
            URLQueryItem(name: "transcodingContainer", value: "ts"),
            URLQueryItem(name: "transcodingProtocol", value: "hls"),
            URLQueryItem(name: "audioCodec", value: "aac"),
            URLQueryItem(name: "ApiKey", value: session.accessToken),
        ]
        let url = components?.url ?? session.serverURL
        return AudioStream(url: url, playMethod: .directPlay)
    }

    private func hlsFallbackURL(track: MediaItem, session: UserSession, playSessionID: String) -> URL {
        var components = URLComponents(url: session.serverURL.appending(path: "/Audio/\(track.id)/main.m3u8"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "mediaSourceId", value: track.id),
            URLQueryItem(name: "playSessionId", value: playSessionID),
            URLQueryItem(name: "deviceId", value: session.deviceID),
            URLQueryItem(name: "audioCodec", value: "aac"),
            URLQueryItem(name: "segmentContainer", value: "ts"),
            URLQueryItem(name: "ApiKey", value: session.accessToken),
        ]
        return components?.url ?? session.serverURL
    }

    func reportStart(_ report: PlaybackReport, session: UserSession) async throws {
        try await post("/Sessions/Playing", report, session, "start")
    }

    func reportProgress(_ report: PlaybackReport, session: UserSession) async throws {
        try await post("/Sessions/Playing/Progress", report, session, "progress")
    }

    func reportStopped(_ report: PlaybackReport, session: UserSession) async throws {
        try await post("/Sessions/Playing/Stopped", report, session, "stopped")
    }

    private func post(_ path: String, _ report: PlaybackReport, _ session: UserSession, _ kind: String) async throws {
        do {
            try await client.post(path, body: PlaybackMapper.body(from: report), auth: context(session))
        } catch {
            AppLogger.network.error("playback \(kind) report failed for item \(report.itemID): \(error)")
            throw error
        }
    }

    private func context(_ session: UserSession) -> AuthContext {
        AuthContext(baseURL: session.serverURL, deviceID: session.deviceID, appVersion: appVersion, token: session.accessToken)
    }
}
