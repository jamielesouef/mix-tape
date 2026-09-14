//  PosterShelfIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

enum PosterShelfIdentifiers {
    static let shelf = "posterShelf.shelf"
    static let titleLabel = "posterShelf.titleLabel"

    static func cell(_ itemID: String) -> String {
        "posterShelf.cell.\(itemID)"
    }
}
