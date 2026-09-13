//  DeviceProfile.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct DeviceProfile: Encodable, Sendable, Equatable {
    public let name: String
    public let maxStreamingBitrate: Int
    public let directPlayProfiles: [DirectPlayProfile]
    public let transcodingProfiles: [TranscodingProfile]

    public init(name: String, maxStreamingBitrate: Int = 120_000_000, directPlayProfiles: [DirectPlayProfile], transcodingProfiles: [TranscodingProfile] = [TranscodingProfile()]) {
        self.name = name
        self.maxStreamingBitrate = maxStreamingBitrate
        self.directPlayProfiles = directPlayProfiles
        self.transcodingProfiles = transcodingProfiles
    }

    public static let permissive = DeviceProfile(
        name: "mixtape",
        directPlayProfiles: [DirectPlayProfile(container: "mp4,m4v,mov,mkv,webm", videoCodec: "h264,hevc,vp9,av1", audioCodec: "aac,mp3,ac3,eac3,flac,alac,opus,dts")],
    )

    public static let forceTranscode = DeviceProfile(
        name: "mixtape-force-transcode",
        directPlayProfiles: [DirectPlayProfile(container: "webm", videoCodec: "vp9", audioCodec: "opus")],
    )

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case maxStreamingBitrate = "MaxStreamingBitrate"
        case directPlayProfiles = "DirectPlayProfiles"
        case transcodingProfiles = "TranscodingProfiles"
    }
}
