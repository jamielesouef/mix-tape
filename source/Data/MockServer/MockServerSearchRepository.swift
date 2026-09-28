//  MockServerSearchRepository.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation

/// Stands in for a real `/Items?searchTerm=` call behind `SearchRepositoryProtocol`,
/// matching against `MockServerDataset` by album or track name and by artist.
struct MockServerSearchRepository: SearchRepositoryProtocol {
    func search(query: String, session _: UserSession) async throws -> SearchResult {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard needle.isEmpty == false else {
            return .empty
        }

        return SearchResult(
            albums: MockServerDataset.albums.filter { Self.matches($0, needle: needle) },
            tracks: MockServerDataset.allTracks.filter { Self.matches($0, needle: needle) }
        )
    }

    // MARK: - Private

    private static func matches(_ item: MediaItem, needle: String) -> Bool {
        item.name.lowercased().contains(needle)
            || (item.albumArtist?.lowercased().contains(needle) ?? false)
    }
}
