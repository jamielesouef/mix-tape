// SPDX-License-Identifier: MIT
//
//  ServerStatus.swift
//  MixTape
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

struct ServerStatus: Equatable {
  let apiVersion: Int
  let serverVersion: String
  let claimed: Bool
}
