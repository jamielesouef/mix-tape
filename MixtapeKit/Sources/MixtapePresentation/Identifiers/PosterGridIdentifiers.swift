//  PosterGridIdentifiers.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public enum PosterGridIdentifiers {
    public static let grid = "posterGrid.grid"

    public static func cell(_ itemID: String) -> String {
        "posterGrid.cell.\(itemID)"
    }
}
