//  PageRequest.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct PageRequest: Sendable, Equatable {
    public let startIndex: Int
    public let limit: Int

    public init(startIndex: Int, limit: Int) {
        self.startIndex = startIndex
        self.limit = limit
    }
}
