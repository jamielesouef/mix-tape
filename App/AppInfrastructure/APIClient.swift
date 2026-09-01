// SPDX-License-Identifier: MIT
//
//  APIClient.swift
//  MixTape
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

import Foundation
import Shared

actor APIClient {
  private let baseURL: URL
  private let session: URLSession

  init(baseURL: URL, session: URLSession = .shared) {
    self.baseURL = baseURL
    self.session = session
  }

  func get<Response: Decodable>(_ path: String) async throws -> Response {
    let url = baseURL.appendingPathComponent(path)
    let (data, response) = try await session.data(from: url)
    guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
      throw APIClientError.badResponse
    }
    return try MixTapeJSON.decoder.decode(Response.self, from: data)
  }
}
