//  PosterShelfIdentifiers.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

public enum PosterShelfIdentifiers {
    public static let shelf = "posterShelf.shelf"
    public static let titleLabel = "posterShelf.titleLabel"

    public static func cell(_ itemID: String) -> String {
        "posterShelf.cell.\(itemID)"
    }
}
