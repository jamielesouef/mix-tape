//  PlaceholderImageURLBuilder.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import Foundation
import MixtapeDomain
import MixtapeUseCase

nonisolated struct PlaceholderImageURLBuilder: ImageURLBuilderProtocol {
    func url(itemID _: String, tag _: String?, kind _: ImageKind, maxHeight _: Int, session _: UserSession) -> URL? {
        nil
    }
}
