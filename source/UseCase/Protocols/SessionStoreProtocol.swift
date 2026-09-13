//  SessionStoreProtocol.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated protocol SessionStoreProtocol: Sendable {
    func load() throws -> UserSession?
    func save(_ session: UserSession) throws
    func clear() throws
}
