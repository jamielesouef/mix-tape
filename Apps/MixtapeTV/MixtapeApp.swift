//  MixtapeApp.swift
//  MixtapeTV
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapePresentation
import SwiftUI

@main
struct MixtapeApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootScreen()
                .environment(\.sessionService, container.sessionService)
                .environment(\.libraryService, container.libraryService)
                .environment(\.seriesService, container.seriesService)
                .environment(\.imageService, container.imageService)
                .environment(\.videoPlaybackService, container.videoPlaybackService)
                .environment(\.musicPlayerService, container.musicPlayerService)
        }
    }
}
