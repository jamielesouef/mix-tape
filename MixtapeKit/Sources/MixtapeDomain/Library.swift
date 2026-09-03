//  Library.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct Library: Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let kind: LibraryKind
    let imageTag: String?
}
