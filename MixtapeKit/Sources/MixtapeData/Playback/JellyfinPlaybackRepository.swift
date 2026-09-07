//  JellyfinPlaybackRepository.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeInfrastructure
import MixtapeUseCase

/// Engineering doc §8 "Playback resolution" and "Progress reporting". Stateless; the device
/// profile is injected so the DEBUG force-transcode profile can replace the shipped one (fork F3).
public nonisolated struct JellyfinPlaybackRepository: PlaybackRepositoryProtocol {
    private let client: JellyfinHTTPClient
    private let appVersion: String
    private let deviceProfile: DeviceProfile

    public init(client: JellyfinHTTPClient, appVersion: String, deviceProfile: DeviceProfile) {
        self.client = client
        self.appVersion = appVersion
        self.deviceProfile = deviceProfile
    }

    public func resolveVideo(itemID: String, startAt: Duration, session: UserSession) async throws -> VideoSourceResolution {
        let dto: PlaybackInfoResponseDTO = try await client.post(
            "/Items/\(itemID)/PlaybackInfo",
            body: PlaybackInfoBody(deviceProfile: deviceProfile, startTimeTicks: startAt.ticks),
            query: [URLQueryItem(name: "userId", value: session.userID)],
            auth: context(session),
        )
        return try PlaybackMapper.resolution(from: dto)
    }

    /// `/Audio/{itemId}/universal` with the native-container list and no bitrate cap (decision 43),
    /// authenticated with `ApiKey` in the query (decision 42). A non-decodable container falls back
    /// to `main.m3u8` directly (Triage 24; `SPEC-DECISIONS.md` 51) rather than `universal`, whose
    /// master playlist joins `TranscodeReasons` with unencoded spaces Kestrel rejects with 400.
    public func audioStream(track: MediaItem, session: UserSession, playSessionID: String) -> AudioStream {
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

    /// `GetVariantHlsAudioPlaylist` requested directly with the client's own query, so its own
    /// segment URIs inherit a space-free query the way `universal`'s master playlist did not
    /// (Triage 24). `segmentContainer`, not `transcodingContainer`, is what this operation declares.
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

    /// All three reports share one body (§8; decision 32). Each is logged on `network` and
    /// rethrown; the use case decides to swallow (§8).
    public func reportStart(_ report: PlaybackReport, session: UserSession) async throws {
        try await post("/Sessions/Playing", report, session, "start")
    }

    public func reportProgress(_ report: PlaybackReport, session: UserSession) async throws {
        try await post("/Sessions/Playing/Progress", report, session, "progress")
    }

    public func reportStopped(_ report: PlaybackReport, session: UserSession) async throws {
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
