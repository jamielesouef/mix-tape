//
//  HomeScreen.swift
//  MixTape
//
//  Created by Jamie Le Souef on 13/9/2026.
//

import SwiftUI

struct HomeScreen: View {
    // MARK: - Properties

    @Environment(\.sessionService) private var sessionService: SessionService

    init() {}

    // MARK: - Body

    var body: some View {
        Group {
            switch sessionService.state {
            case .loading:
                SplashScreen()
            case .signedOut:
                SignInFlow()
            case .signedIn:
                Text("Hi")
            }
        }
        .task {
            if sessionService.state == .loading {
                await sessionService.restore()
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loading") {
        HomeScreen().environment(\.sessionService, MockSessionService.loading())
    }

    #Preview("signed out") {
        HomeScreen().environment(\.sessionService, MockSessionService.signedOut())
    }

    #Preview("signed in") {
        HomeScreen()
            .environment(\.sessionService, MockSessionService.signedIn())
            .environment(\.libraryService, MockLibraryService.loaded())
    }
#endif
