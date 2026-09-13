//  MockImageURLBuilder.swift
//  MixtapeUseCase
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if DEBUG
    import Foundation
    import MixtapeDomain

    public nonisolated struct MockImageURLBuilder: ImageURLBuilderProtocol {
        public init() {}

        public func url(itemID: String, tag: String?, kind: ImageKind, maxHeight: Int, session _: UserSession) -> URL? {
            guard let tag else { return nil }
            let name = kind == .primary ? "Primary" : "Backdrop"
            return URL(string: "mock://images/\(itemID)/\(name)?tag=\(tag)&maxHeight=\(maxHeight)")
        }
    }
#endif
