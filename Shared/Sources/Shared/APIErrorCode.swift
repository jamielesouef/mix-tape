//
//  APIErrorCode.swift
//  Shared
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

public enum APIErrorCode: String, Codable, Sendable {
  case invalidIdentityToken
  case notOwner
  case unauthorized
  case notFound
  case scanInProgress
  case internalError
}
