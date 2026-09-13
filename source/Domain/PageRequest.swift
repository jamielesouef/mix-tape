//  PageRequest.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct PageRequest: Sendable, Equatable {
    let startIndex: Int
    let limit: Int

    init(startIndex: Int, limit: Int) {
        self.startIndex = startIndex
        self.limit = limit
    }
}
