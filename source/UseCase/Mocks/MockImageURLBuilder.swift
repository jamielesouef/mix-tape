//  MockImageURLBuilder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

#if DEBUG
    struct MockImageURLBuilder: ImageURLBuilderProtocol {
        /// Previews want a real picture, so the path is a placeholder image of the requested
        /// size. The item and tag ride along as query items: the placeholder host ignores
        /// them, and they keep the builder's inputs visible to tests.
        func url(
            itemID: String,
            tag: String?,
            kind: ImageKind,
            maxHeight: Int,
            session _: UserSession
        ) -> URL? {
            guard let tag else {
                return nil
            }

            let width = kind == .primary ? maxHeight : maxHeight * 16 / 9

            var components = URLComponents(string: "https://placecats.com/\(width)/\(maxHeight)")
            components?.queryItems = [
                URLQueryItem(name: "itemId", value: itemID),
                URLQueryItem(name: "tag", value: tag)
            ]

            return components?.url
        }
    }
#endif
