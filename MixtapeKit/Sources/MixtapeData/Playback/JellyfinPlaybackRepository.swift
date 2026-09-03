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

    /// Logged on `network` and rethrown; the use case decides to swallow (§8).
    public func reportStart(_ report: PlaybackReport, session: UserSession) async throws {
        do {
            try await client.post("/Sessions/Playing", body: PlaybackMapper.body(from: report), auth: context(session))
        } catch {
            AppLogger.network.error("playback start report failed for item \(report.itemID): \(error)")
            throw error
        }
    }

    private func context(_ session: UserSession) -> AuthContext {
        AuthContext(baseURL: session.serverURL, deviceID: session.deviceID, appVersion: appVersion, token: session.accessToken)
    }
}
