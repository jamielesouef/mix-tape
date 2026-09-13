//  MockImageURLBuilder.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation

#if DEBUG
    import Foundation

    nonisolated struct MockImageURLBuilder: ImageURLBuilderProtocol {
        init() {}

        func url(itemID: String, tag: String?, kind: ImageKind, maxHeight: Int, session _: UserSession) -> URL? {
            guard let tag else { return nil }
            let name = kind == .primary ? "Primary" : "Backdrop"
            return URL(string: "mock://images/\(itemID)/\(name)?tag=\(tag)&maxHeight=\(maxHeight)")
        }
    }
#endif
