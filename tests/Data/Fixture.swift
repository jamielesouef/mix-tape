//  Fixture.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import Foundation
import Testing
@testable import Mixtape

// A class, not an enum, so `Bundle(for:)` can find the test bundle. There is no
// `Bundle.module` outside a Swift package.
final class Fixture {
    static func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: Fixture.self)
        let url = try #require(bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
