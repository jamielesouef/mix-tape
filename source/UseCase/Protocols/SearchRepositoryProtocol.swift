//  SearchRepositoryProtocol.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

nonisolated protocol SearchRepositoryProtocol: Sendable {
    func search(query: String, session: UserSession) async throws -> SearchResult
}
