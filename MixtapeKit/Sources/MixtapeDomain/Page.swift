//  Page.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct Page<Element: Sendable>: Sendable {
    let items: [Element]
    let totalCount: Int
    let startIndex: Int
}
