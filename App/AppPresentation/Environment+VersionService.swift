//
//  Environment+VersionService.swift
//  MixTape
//
//  Created by Jamie Le Souëf on 31/08/2026.
//

import SwiftUI

// Held once and referenced below rather than called inline at the `@Entry`
// site — a class-type default re-evaluated on every access invalidates its
// dependents on every read, which is exactly what the `@Entry` macro warns
// against for reference types.
private let defaultVersionService = VersionService.placeholder()

extension EnvironmentValues {
  @Entry var versionService: VersionService = defaultVersionService
}
