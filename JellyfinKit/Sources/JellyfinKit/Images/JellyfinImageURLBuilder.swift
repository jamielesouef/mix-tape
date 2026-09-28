//  JellyfinImageURLBuilder.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

public struct JellyfinImageURLBuilder: Sendable {
    public init() {}

    /// The URL for one of an item's images, or `nil` when the item has no tag for it.
    public func url(
        serverURL: URL,
        itemID: String,
        tag: String?,
        type: JellyfinImageType,
        maxHeight: Int
    ) -> URL? {
        guard let tag else {
            return nil
        }

        let path =
            switch type {
            case .primary: "/Items/\(itemID)/Images/Primary"
            case .backdrop: "/Items/\(itemID)/Images/Backdrop/0"
            }

        var components = URLComponents(
            url: serverURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "tag", value: tag),
            URLQueryItem(name: "maxHeight", value: String(maxHeight)),
            URLQueryItem(name: "quality", value: String(Self.jpegQuality))
        ]

        return components?.url
    }

    // MARK: - Private

    /// Jellyfin re-encodes on the way out; 90 keeps sleeve art clean without a large payload.
    private static let jpegQuality = 90
}
