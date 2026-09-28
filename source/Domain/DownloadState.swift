//  DownloadState.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

enum DownloadState: Sendable, Equatable {
    case notDownloaded
    case waitingForWiFi
    case downloading(progress: Double)
    case downloaded
    case failed(MixtapeError)
}
