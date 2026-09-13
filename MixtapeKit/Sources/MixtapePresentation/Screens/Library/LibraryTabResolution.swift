//  LibraryTabResolution.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 05/09/2026.
//

import MixtapeDomain

nonisolated enum LibraryTabResolution: Equatable {
    case none
    case one(Library)
    case several([Library])

    init(kind: LibraryKind, in libraries: [Library]) {
        let matching = libraries.filter { $0.kind == kind }
        switch matching.count {
        case 0: self = .none
        case 1: self = .one(matching[0])
        default: self = .several(matching)
        }
    }
}
