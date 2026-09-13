//  ImageURLBuilderProtocol.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

public nonisolated protocol ImageURLBuilderProtocol: Sendable {
    func url(itemID: String, tag: String?, kind: ImageKind, maxHeight: Int, session: UserSession) -> URL?
}
