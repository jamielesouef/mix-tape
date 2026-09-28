//  DownloadState+IsActive.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

extension DownloadState {
    /// Whether a download is already in flight — waiting for Wi-Fi counts, since starting a
    /// new download for the same album would race the one already pending.
    var isActive: Bool {
        switch self {
        case .downloading,
             .waitingForWiFi: true
        case .notDownloaded,
             .downloaded,
             .failed: false
        }
    }
}
