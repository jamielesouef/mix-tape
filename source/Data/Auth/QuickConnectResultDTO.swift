//  QuickConnectResultDTO.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

struct QuickConnectResultDTO: Decodable {
    let authenticated: Bool
    let secret: String?
    let code: String?

    enum CodingKeys: String, CodingKey {
        case authenticated = "Authenticated"
        case secret = "Secret"
        case code = "Code"
    }

    /// The spec marks `Authenticated` optional with no default — absent reads as
    /// not-yet-authenticated rather than surfacing an optional through the whole call chain.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        authenticated = try container.decodeIfPresent(Bool.self, forKey: .authenticated) ?? false
        secret = try container.decodeIfPresent(String.self, forKey: .secret)
        code = try container.decodeIfPresent(String.self, forKey: .code)
    }
}
