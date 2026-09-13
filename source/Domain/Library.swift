//  Library.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct Library: Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: LibraryKind
    let imageTag: String?

    init(id: String, name: String, kind: LibraryKind, imageTag: String?) {
        self.id = id
        self.name = name
        self.kind = kind
        self.imageTag = imageTag
    }
}
