//  EmptyBody.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// Body for a `POST` whose endpoint takes none; encodes as `{}`.
public nonisolated struct EmptyBody: Encodable, Sendable {
    public init() {}
}
