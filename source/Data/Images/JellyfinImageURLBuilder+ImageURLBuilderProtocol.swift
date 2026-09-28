//  JellyfinImageURLBuilder+ImageURLBuilderProtocol.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation
import JellyfinKit

extension JellyfinImageURLBuilder: ImageURLBuilderProtocol {
    func url(
        itemID: String,
        tag: String?,
        kind: ImageKind,
        maxHeight: Int,
        session: UserSession
    ) -> URL? {
        let type: JellyfinImageType =
            switch kind {
            case .primary: .primary
            case .backdrop: .backdrop
            }

        return url(
            serverURL: session.serverURL,
            itemID: itemID,
            tag: tag,
            type: type,
            maxHeight: maxHeight
        )
    }
}
