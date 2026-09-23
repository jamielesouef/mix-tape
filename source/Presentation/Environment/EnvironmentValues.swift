//  EnvironmentValues+ImageService.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

extension EnvironmentValues {
    /// SwiftUI reads environment defaults on the main actor, so the placeholder is reachable.
    @Entry var imageService: ImageService = MainActor.assumeIsolated { .placeholder }
    @Entry var libraryService: LibraryService = MainActor.assumeIsolated { .placeholder }
    @Entry var musicPlayerService: MusicPlayerService = MainActor.assumeIsolated { .placeholder }
    @Entry var sessionService: SessionService = MainActor.assumeIsolated { .placeholder }
}
