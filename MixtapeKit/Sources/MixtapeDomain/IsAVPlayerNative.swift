//  IsAVPlayerNative.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// Whether AVPlayer can play the source directly. Container ∈ {mp4, m4v, mov} and video
/// codec ∈ {h264, hevc} and the audio codec is absent (no audio track, decision 39) or
/// ∈ {aac, mp3, alac, ac3, eac3}. Comparison is case-insensitive.
nonisolated func isAVPlayerNative(container: String, videoCodec: String?, audioCodec: String?) -> Bool {
    let containers: Set = ["mp4", "m4v", "mov"]
    let videoCodecs: Set = ["h264", "hevc"]
    let audioCodecs: Set = ["aac", "mp3", "alac", "ac3", "eac3"]
    guard containers.contains(container.lowercased()) else { return false }
    guard let videoCodec, videoCodecs.contains(videoCodec.lowercased()) else { return false }
    guard let audioCodec else { return true }
    return audioCodecs.contains(audioCodec.lowercased())
}
