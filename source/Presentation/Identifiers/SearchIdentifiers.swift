//  SearchIdentifiers.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

enum SearchIdentifiers {
    static let field = "search.field"
    static let emptyLabel = "search.emptyLabel"
    static let offlineLabel = "search.offlineLabel"
    static let doneButton = "search.doneButton"

    static func albumRow(_ albumID: String) -> String {
        "search.albumRow.\(albumID)"
    }

    static func trackRow(_ trackID: String) -> String {
        "search.trackRow.\(trackID)"
    }
}
