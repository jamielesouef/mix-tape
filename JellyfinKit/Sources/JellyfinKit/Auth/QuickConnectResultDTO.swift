//  QuickConnectResultDTO.swift
//  JellyfinKit
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

public struct QuickConnectResultDTO: Decodable, Sendable {
    public let authenticated: Bool
    public let secret: String?
    public let code: String?

    enum CodingKeys: String, CodingKey {
        case authenticated = "Authenticated"
        case secret = "Secret"
        case code = "Code"
    }

    /// The spec marks `Authenticated` optional with no default — absent reads as
    /// not-yet-authenticated rather than surfacing an optional through the whole call chain.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        authenticated = try container.decodeIfPresent(Bool.self, forKey: .authenticated) ?? false
        secret = try container.decodeIfPresent(String.self, forKey: .secret)
        code = try container.decodeIfPresent(String.self, forKey: .code)
    }
}
