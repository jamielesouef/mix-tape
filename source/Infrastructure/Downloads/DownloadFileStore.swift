//  DownloadFileStore.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation

/// Owns the on-disk layout for downloaded albums: `<Documents>/Downloads/<albumID>/<trackID>.mp3`.
actor DownloadFileStore {
    private let fileManager = FileManager.default
    private let root: URL

    init(root: URL = DownloadFileStore.defaultRoot()) {
        self.root = root
    }

    static func defaultRoot() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        return documents.appending(path: "Downloads", directoryHint: .isDirectory)
    }

    func store(tempURL: URL, albumID: String, trackID: String) throws {
        let directory = try albumDirectory(albumID: albumID)
        let target = directory.appending(path: "\(trackID).mp3")

        if fileManager.fileExists(atPath: target.path()) {
            try fileManager.removeItem(at: target)
        }

        try fileManager.moveItem(at: tempURL, to: target)
    }

    func localURL(albumID: String, trackID: String) -> URL? {
        let target = root.appending(path: albumID).appending(path: "\(trackID).mp3")

        return fileManager.fileExists(atPath: target.path()) ? target : nil
    }

    func hasAllTracks(albumID: String, trackIDs: [String]) -> Bool {
        trackIDs.allSatisfy { localURL(albumID: albumID, trackID: $0) != nil }
    }

    func bytesOnDisk(albumID: String) -> Int64 {
        let directory = root.appending(path: albumID)

        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }

        return files.reduce(Int64(0)) { total, url in
            let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            return total + Int64(size ?? 0)
        }
    }

    func downloadedAlbumIDs() -> [String] {
        guard let entries = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return entries.map(\.lastPathComponent)
    }

    func totalBytesOnDisk() -> Int64 {
        guard let albumDirectories = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ) else {
            return 0
        }

        return albumDirectories.reduce(Int64(0)) { $0 + bytesOnDisk(albumID: $1.lastPathComponent) }
    }

    func removeAlbum(albumID: String) throws {
        let directory = root.appending(path: albumID)

        guard fileManager.fileExists(atPath: directory.path()) else {
            return
        }

        try fileManager.removeItem(at: directory)
    }

    func removeAll() throws {
        guard fileManager.fileExists(atPath: root.path()) else {
            return
        }

        try fileManager.removeItem(at: root)
    }

    // MARK: - Private

    private func albumDirectory(albumID: String) throws -> URL {
        let directory = root.appending(path: albumID)

        if fileManager.fileExists(atPath: directory.path()) == false {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }
}
