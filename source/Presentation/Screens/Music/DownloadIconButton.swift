//  DownloadIconButton.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import SwiftUI

/// The album download control for the right-side toolbar — arrow while downloadable, a
/// progress ring while downloading, a checkmark with a Remove Download menu once complete,
/// and a retry affordance on failure. Always acts on `album`, even while another album plays.
struct DownloadIconButton: View {
    // MARK: - Properties

    @Environment(\.downloadsService) private var downloadsService: DownloadsService
    let album: MediaItem
    let tracks: [MediaItem]

    // MARK: - Body

    var body: some View {
        Group {
            switch downloadsService.state(for: album.id) {
            case .notDownloaded:
                Button { Task { await downloadsService.start(album: album, tracks: tracks) } } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .disabled(tracks.isEmpty)
                .accessibilityLabel("Download album")

            case .waitingForWiFi:
                Button { Task { await downloadsService.cancel(albumID: album.id) } } label: {
                    Image(systemName: "wifi.slash")
                }
                .accessibilityLabel("Waiting for Wi-Fi to download. Tap to cancel.")

            case let .downloading(progress):
                Button { Task { await downloadsService.cancel(albumID: album.id) } } label: {
                    ProgressView(value: progress)
                        .progressViewStyle(.circular)
                }
                .accessibilityLabel("Downloading, \(Int(progress * 100)) percent complete. Tap to cancel.")

            case .downloaded:
                Menu {
                    Button("Remove Download", systemImage: "trash", role: .destructive) {
                        Task { await downloadsService.remove(albumID: album.id) }
                    }
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .accessibilityLabel("Downloaded. Tap for download options.")

            case .failed:
                Button { Task { await downloadsService.start(album: album, tracks: tracks) } } label: {
                    Image(systemName: "exclamationmark.circle")
                }
                .accessibilityLabel("Download failed. Tap to retry.")
            }
        }
        .accessibilityIdentifier(AlbumDetailIdentifiers.downloadButton)
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        DownloadIconButton(album: MockMedia.albums[0], tracks: MockMedia.tracks)
            .environment(\.downloadsService, MockDownloadsService.downloading())
    }

    #Preview("empty") {
        DownloadIconButton(album: MockMedia.albums[0], tracks: MockMedia.tracks)
            .environment(\.downloadsService, MockDownloadsService.idle())
    }

    #Preview("failure") {
        DownloadIconButton(album: MockMedia.albums[0], tracks: [])
            .environment(
                \.downloadsService,
                MockDownloadsService.make(downloads: ["album-1": .failed(.serverUnreachable)])
            )
    }
#endif
