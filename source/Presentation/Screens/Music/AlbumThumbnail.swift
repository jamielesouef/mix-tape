//  AlbumThumbnail.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import SwiftUI

/// One album's artwork with its title and artist underneath — the shape a wallet shelf row
/// repeats horizontally on `WalletsHomeScreen`.
struct AlbumThumbnail: View {
    // MARK: - Properties

    let album: MediaItem
    var isDownloaded = false
    var isPlaying = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RemoteImage(source: .item(album, .primary), maxHeight: 300, placeholder: "music.note")
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay {
                        if isPlaying {
                            RoundedRectangle(cornerRadius: 8).strokeBorder(.tint, lineWidth: 3)
                        }
                    }

                if isDownloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .symbolRenderingMode(.multicolor)
                        .padding(4)
                        .accessibilityLabel("Downloaded")
                }
            }
            .frame(width: 120, height: 120)

            Text(album.name)
                .font(.subheadline)
                .lineLimit(1)
            Text(album.albumArtist ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 120)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        AlbumThumbnail(album: MockMedia.albums[0], isDownloaded: true, isPlaying: true)
            .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        AlbumThumbnail(album: MockMedia.albums[1])
    }

    #Preview("failure") {
        AlbumThumbnail(album: MockMedia.albums[2])
            .environment(
                \.imageService,
                MockImageService.make(sessionService: MockSessionService.signedOut())
            )
    }
#endif
