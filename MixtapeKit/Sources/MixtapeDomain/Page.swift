//  Page.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public nonisolated struct Page<Element: Sendable>: Sendable {
    public let items: [Element]
    public let totalCount: Int
    public let startIndex: Int

    public init(items: [Element], totalCount: Int, startIndex: Int) {
        self.items = items
        self.totalCount = totalCount
        self.startIndex = startIndex
    }
}
