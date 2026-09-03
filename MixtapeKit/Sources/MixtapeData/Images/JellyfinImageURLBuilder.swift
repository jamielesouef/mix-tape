//  JellyfinImageURLBuilder.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeUseCase

/// Engineering doc §8 "Images", corrected by decision 25: `maxHeight` (not `fillHeight`), `nil`
/// without a tag, and no auth — image requests are anonymous on this server.
public nonisolated struct JellyfinImageURLBuilder: ImageURLBuilderProtocol {
    public init() {}

    public func url(itemID: String, tag: String?, kind: ImageKind, maxHeight: Int, session: UserSession) -> URL? {
        guard let tag else { return nil }
        let path = switch kind {
        case .primary: "/Items/\(itemID)/Images/Primary"
        case .backdrop: "/Items/\(itemID)/Images/Backdrop/0"
        }
        var components = URLComponents(url: session.serverURL.appending(path: path), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "tag", value: tag),
            URLQueryItem(name: "maxHeight", value: String(maxHeight)),
            URLQueryItem(name: "quality", value: "90"),
        ]
        return components?.url
    }
}
