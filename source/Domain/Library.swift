//  Library.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

struct Library: Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: LibraryKind
    let imageTag: String?
}
