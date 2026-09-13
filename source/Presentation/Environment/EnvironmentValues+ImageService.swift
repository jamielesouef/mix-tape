//  EnvironmentValues+ImageService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

extension EnvironmentValues {
    /// SwiftUI reads environment defaults on the main actor, so the placeholder is reachable.
    @Entry var imageService: ImageService = MainActor.assumeIsolated { .placeholder }
}
