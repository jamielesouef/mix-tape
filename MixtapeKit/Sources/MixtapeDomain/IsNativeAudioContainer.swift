//  IsNativeAudioContainer.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated func isNativeAudioContainer(_ container: String?) -> Bool {
    guard let container else { return true }
    let decodable: Set = ["flac", "alac", "m4a", "m4b", "mp3", "aac", "wav", "aiff", "aif", "mp4", "mov"]
    let tokens = container.lowercased().split(whereSeparator: { $0 == "," || $0 == " " }).map(String.init)
    return tokens.contains { decodable.contains($0) }
}
