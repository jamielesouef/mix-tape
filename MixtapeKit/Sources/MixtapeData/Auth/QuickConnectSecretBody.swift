//  QuickConnectSecretBody.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct QuickConnectSecretBody: Encodable {
    let secret: String

    enum CodingKeys: String, CodingKey {
        case secret = "Secret"
    }
}
