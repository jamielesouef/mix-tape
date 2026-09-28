//  AlbumDownload.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

struct AlbumDownload: Sendable, Equatable, Identifiable {
    let id: String
    let albumID: String
    let albumTitle: String
    let state: DownloadState
    let bytesOnDisk: Int64
}
