//  ImageURLBuilderProtocol.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain

/// Builds an image URL for an item, or `nil` when the item has no image of that kind (decision 25).
public nonisolated protocol ImageURLBuilderProtocol: Sendable {
    func url(itemID: String, tag: String?, kind: ImageKind, maxHeight: Int, session: UserSession) -> URL?
}
