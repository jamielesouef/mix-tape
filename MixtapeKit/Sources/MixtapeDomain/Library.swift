//  Library.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct Library: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let kind: LibraryKind
    public let imageTag: String?

    public init(id: String, name: String, kind: LibraryKind, imageTag: String?) {
        self.id = id
        self.name = name
        self.kind = kind
        self.imageTag = imageTag
    }
}
