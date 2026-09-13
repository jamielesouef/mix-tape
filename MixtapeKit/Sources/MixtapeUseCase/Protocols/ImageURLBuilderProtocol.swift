//  ImageURLBuilderProtocol.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import MixtapeDomain

public nonisolated protocol ImageURLBuilderProtocol: Sendable {
    func url(itemID: String, tag: String?, kind: ImageKind, maxHeight: Int, session: UserSession) -> URL?
}
