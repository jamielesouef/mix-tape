//  Page.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct Page<Element: Sendable>: Sendable {
    let items: [Element]
    let totalCount: Int
    let startIndex: Int

    init(items: [Element], totalCount: Int, startIndex: Int) {
        self.items = items
        self.totalCount = totalCount
        self.startIndex = startIndex
    }
}

extension Page: Equatable where Element: Equatable {}
