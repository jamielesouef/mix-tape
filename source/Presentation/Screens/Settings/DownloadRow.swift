//  DownloadRow.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation
import SwiftUI

/// One album's row in the Downloads settings list: its status, the space it uses on disk once
/// known, and the one action that fits its current `DownloadState`.
struct DownloadRow: View {
    // MARK: - Properties

    let album: MediaItem
    let state: DownloadState
    let bytes: Int64?
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(album.name)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let bytes, bytes > 0 {
                Text(bytes.formatted(.byteCount(style: .file)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(actionTitle, role: actionRole, action: action)
                .buttonStyle(.bordered)
        }
        .accessibilityIdentifier(SettingsIdentifiers.downloadRow(album.id))
    }

    // MARK: - Private

    private var statusText: String {
        switch state {
        case .notDownloaded: "Not downloaded"
        case .waitingForWiFi: "Waiting for Wi-Fi"
        case let .downloading(progress): "Downloading — \(Int(progress * 100))%"
        case .downloaded: "Downloaded"
        case .failed: "Failed"
        }
    }

    private var actionTitle: String {
        switch state {
        case .notDownloaded,
             .downloaded: "Remove"
        case .waitingForWiFi,
             .downloading: "Cancel"
        case .failed: "Retry"
        }
    }

    private var actionRole: ButtonRole? {
        switch state {
        case .notDownloaded,
             .downloaded,
             .waitingForWiFi,
             .downloading: .destructive
        case .failed: nil
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        List {
            DownloadRow(album: MockMedia.albums[0], state: .downloaded, bytes: 734_003, action: {})
        }
    }

    #Preview("empty") {
        List {
            DownloadRow(
                album: MockMedia.albums[0],
                state: .downloading(progress: 0.5),
                bytes: nil,
                action: {}
            )
        }
    }

    #Preview("failure") {
        List {
            DownloadRow(
                album: MockMedia.albums[0],
                state: .failed(.serverUnreachable),
                bytes: nil,
                action: {}
            )
        }
    }
#endif
