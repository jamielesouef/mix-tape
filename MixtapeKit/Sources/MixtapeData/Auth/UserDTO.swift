//  UserDTO.swift
//  MixtapeData
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

nonisolated struct UserDTO: Decodable {
    let id: String?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}
