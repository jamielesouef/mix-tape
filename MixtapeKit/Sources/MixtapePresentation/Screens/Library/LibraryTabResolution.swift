//  LibraryTabResolution.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 05/09/2026.
//

import MixtapeDomain

/// What a tvOS kind tab hosts for the libraries the user has (engineering doc §1.5, slice 016): the
/// one library of its kind, a list of them when there are several, or the empty state. Pure and
/// platform-shared so the rule is testable without the tvOS-only `LibraryTabScreen`.
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
