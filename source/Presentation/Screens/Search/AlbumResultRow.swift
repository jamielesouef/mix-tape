//  AlbumResultRow.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation
import SwiftUI

struct AlbumResultRow: View {
    // MARK: - Properties

    let album: MediaItem

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(source: .item(album, .primary), maxHeight: 120, placeholder: "music.note")
                .frame(width: 44, height: 44)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading) {
                Text(album.name)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Private

    private var subtitle: String {
        [album.albumArtist, album.productionYear.map { $0.formatted(.number.grouping(.never)) }]
            .compactMap(\.self)
            .joined(separator: " · ")
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        List {
            AlbumResultRow(album: MockMedia.albums[0])
        }
        .environment(\.imageService, MockImageService.make())
    }

    #Preview("empty") {
        List {
            AlbumResultRow(album: MockMedia.albums[1])
        }
    }

    #Preview("failure") {
        List {
            AlbumResultRow(album: MockMedia.albums[2])
        }
        .environment(
            \.imageService,
            MockImageService.make(sessionService: MockSessionService.signedOut())
        )
    }
#endif
