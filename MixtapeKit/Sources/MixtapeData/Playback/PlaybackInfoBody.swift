//  PlaybackInfoBody.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// Request body for `POST /Items/{itemId}/PlaybackInfo` (engineering doc §8).
nonisolated struct PlaybackInfoBody: Encodable {
    let deviceProfile: DeviceProfile
    let startTimeTicks: Int64
    let maxStreamingBitrate = 120_000_000
    let enableDirectPlay = true
    let enableDirectStream = true
    let enableTranscoding = true
    let allowVideoStreamCopy = true
    let allowAudioStreamCopy = true
    let autoOpenLiveStream = true

    enum CodingKeys: String, CodingKey {
        case deviceProfile = "DeviceProfile"
        case startTimeTicks = "StartTimeTicks"
        case maxStreamingBitrate = "MaxStreamingBitrate"
        case enableDirectPlay = "EnableDirectPlay"
        case enableDirectStream = "EnableDirectStream"
        case enableTranscoding = "EnableTranscoding"
        case allowVideoStreamCopy = "AllowVideoStreamCopy"
        case allowAudioStreamCopy = "AllowAudioStreamCopy"
        case autoOpenLiveStream = "AutoOpenLiveStream"
    }
}
