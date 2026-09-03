//  SessionService+Placeholder.swift
//  MixtapeServices
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public extension SessionService {
    /// `@Entry` default. Never used by a running app — the composition root always injects one.
    static let placeholder = MockSessionService.signedOut()
}
