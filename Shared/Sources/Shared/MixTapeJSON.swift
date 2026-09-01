// SPDX-License-Identifier: MIT
//
//  MixTapeJSON.swift
//  Shared
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

import Foundation

public enum MixTapeJSON {
  public static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }()

  public static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()
}
