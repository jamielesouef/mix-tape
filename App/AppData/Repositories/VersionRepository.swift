//
//  VersionRepository.swift
//  MixTape
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

import Shared

struct VersionRepository: VersionRepositoryProtocol {
  let client: APIClient

  func fetchVersion() async throws -> ServerStatus {
    do {
      let dto: VersionResponseDTO = try await client.get("version")
      return ServerStatus(apiVersion: dto.apiVersion, serverVersion: dto.serverVersion, claimed: dto.claimed)
    } catch is APIClientError {
      throw VersionFetchError.unexpectedResponse
    } catch {
      throw VersionFetchError.unreachable
    }
  }
}
