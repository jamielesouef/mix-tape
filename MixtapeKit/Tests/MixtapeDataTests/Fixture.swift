//  Fixture.swift
//  MixtapeDataTests
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import Testing

/// Loads a JSON fixture from `Fixtures/` as raw bytes. Captured from the dev server unless the
/// filename says `hand-authored`.
enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
