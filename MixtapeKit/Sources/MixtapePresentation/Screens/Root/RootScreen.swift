//  RootScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeServices
import SwiftUI

/// Switches on `SessionService.state` (engineering doc §10): splash, the sign-in flow, or the tabs.
public struct RootScreen: View {
    @Environment(\.sessionService) private var sessionService

    public init() {}

    public var body: some View {
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
