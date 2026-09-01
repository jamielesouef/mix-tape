//
//  VersionFetchError.swift
//  MixTape
//
//  Created by Jamie Le Souëf on 01/09/2026.
//

enum VersionFetchError: Error, Equatable {
  case unreachable
  case unexpectedResponse
}
