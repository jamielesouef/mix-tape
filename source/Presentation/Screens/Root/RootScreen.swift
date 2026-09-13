//  RootScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

struct RootScreen: View {
    @Environment(\.sessionService) private var sessionService: SessionService

    init() {}

    var body: some View {
        Group {
            switch sessionService.state {
            case .loading:
                SplashScreen()
            case .signedOut:
                SignInFlow()
            case .signedIn:
                RootTabScreen()
            }
        }
        .task {
            if sessionService.state == .loading {
                await sessionService.restore()
            }
        }
    }
}

#if DEBUG
    #Preview("loading") {
        RootScreen().environment(\.sessionService, MockSessionService.loading())
    }

    #Preview("signed out") {
        RootScreen().environment(\.sessionService, MockSessionService.signedOut())
    }

    #Preview("signed in") {
        RootScreen()
            .environment(\.sessionService, MockSessionService.signedIn())
            .environment(\.libraryService, MockLibraryService.loaded())
    }
#endif
