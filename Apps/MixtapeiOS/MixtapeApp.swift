//  MixtapeApp.swift
//  MixtapeiOS
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
        }
    }
}
