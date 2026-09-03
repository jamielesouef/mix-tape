// SPDX-License-Identifier: MIT
//
//  VersionResponseDTOTests.swift
//  MixTapeTests
//
//  Created by Jamie Le Souëf on 01/09/2026.
//

import Foundation
import Testing

import Shared

@Suite
struct VersionResponseDTOTests {
  @Test("Round-trips through MixTapeJSON and preserves the encoded shape")
  func roundTripsThroughMixTapeJSON() async throws {
    let original = VersionResponseDTO(apiVersion: 1, serverVersion: "1.0.0", claimed: true)

    let data = try MixTapeJSON.encoder.encode(original)
    let decoded = try MixTapeJSON.decoder.decode(VersionResponseDTO.self, from: data)

    #expect(decoded == original)

    let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let object = try #require(jsonObject)

    #expect(object["apiVersion"] as? Int == 1)
    #expect(object["serverVersion"] as? String == "1.0.0")
    #expect(object["claimed"] as? Bool == true)
  }
}
