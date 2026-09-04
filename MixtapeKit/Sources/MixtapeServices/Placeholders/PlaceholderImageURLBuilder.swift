//  PlaceholderImageURLBuilder.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeUseCase

/// The release-build builder behind `ImageService.placeholder` (slice 013): no URL for any image,
/// so the placeholder service only ever shows placeholder art.
nonisolated struct PlaceholderImageURLBuilder: ImageURLBuilderProtocol {
    func url(itemID _: String, tag _: String?, kind _: ImageKind, maxHeight _: Int, session _: UserSession) -> URL? {
        nil
    }
}
