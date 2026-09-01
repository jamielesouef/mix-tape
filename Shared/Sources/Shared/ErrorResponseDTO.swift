// SPDX-License-Identifier: MIT
//
//  ErrorResponseDTO.swift
//  Shared
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

public struct ErrorResponseDTO: Codable, Sendable, Hashable {
  public let code: APIErrorCode
  public let message: String

  public init(code: APIErrorCode, message: String) {
    self.code = code
    self.message = message
  }
}
