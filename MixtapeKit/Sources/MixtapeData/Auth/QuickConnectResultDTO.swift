//  QuickConnectResultDTO.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

/// `/QuickConnect/Initiate` and `/QuickConnect/Connect`.
nonisolated struct QuickConnectResultDTO: Decodable {
    let authenticated: Bool?
    let secret: String?
    let code: String?

    enum CodingKeys: String, CodingKey {
        case authenticated = "Authenticated"
        case secret = "Secret"
        case code = "Code"
    }
}
