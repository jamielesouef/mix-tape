//  PageRequest.swift
//  MixtapeDomain
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct PageRequest: Sendable, Equatable {
    let startIndex: Int
    let limit: Int
}
