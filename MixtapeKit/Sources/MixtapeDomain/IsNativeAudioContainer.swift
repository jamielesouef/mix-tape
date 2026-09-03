//  IsNativeAudioContainer.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// Whether a track's container direct-streams from `/Audio/{itemId}/universal` (decision 23): the
/// container list the app requests is `flac,alac,m4a,mp3,aac,wav,aiff`, plus the `mp4`/`mov` family
/// Jellyfin reports for m4a. Jellyfin returns a comma-joined container string, so any decodable
/// token counts. A non-decodable container means the universal endpoint transcodes to HLS.
public nonisolated func isNativeAudioContainer(_ container: String?) -> Bool {
    guard let container else { return true } // no container info: assume the tagged library direct-streams
    let decodable: Set = ["flac", "alac", "m4a", "m4b", "mp3", "aac", "wav", "aiff", "aif", "mp4", "mov"]
    let tokens = container.lowercased().split(whereSeparator: { $0 == "," || $0 == " " }).map(String.init)
    return tokens.contains { decodable.contains($0) }
}
