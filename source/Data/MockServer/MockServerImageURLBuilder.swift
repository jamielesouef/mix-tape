//  MockServerImageURLBuilder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation

/// Stands in for `JellyfinImageURLBuilder` behind `ImageURLBuilderProtocol`. Every image in
/// the app, when running on the mock server, comes from placecats.com — a stable cat per
/// item id, sized to what the caller asked for.
struct MockServerImageURLBuilder: ImageURLBuilderProtocol {
    private static let cats = ["millie", "neo", "bella", "neo_2"]

    func url(
        itemID: String,
        tag: String?,
        kind _: ImageKind,
        maxHeight: Int,
        session _: UserSession
    ) -> URL? {
        guard tag != nil else {
            return nil
        }

        let cat = Self.cats[abs(itemID.hashValue) % Self.cats.count]
        let side = max(120, min(maxHeight, 1200))

        return URL(string: "https://placecats.com/\(cat)/\(side)/\(side)")
    }
}
