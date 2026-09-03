//  SignInFlow+iOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(iOS)
    import MixtapeServices
    import SwiftUI

    /// iOS: server entry, then password sign-in with Quick Connect as the secondary action.
    struct SignInFlow: View {
        @Environment(\.sessionService) private var sessionService
        @State private var usingQuickConnect = false

        var body: some View {
            if sessionService.serverIdentity == nil {
                ServerEntryScreen()
            } else if usingQuickConnect {
                QuickConnectScreen(onCancel: {
                    sessionService.cancelQuickConnect()
                    usingQuickConnect = false
                })
            } else {
                SignInScreen(onUseQuickConnect: { usingQuickConnect = true })
            }
        }
    }

    #Preview("server entry") {
        SignInFlow().environment(\.sessionService, MockSessionService.signedOut())
    }

    #Preview("sign in") {
        SignInFlow().environment(\.sessionService, MockSessionService.serverValidated())
    }

    #Preview("failure") {
        SignInFlow().environment(\.sessionService, MockSessionService.failed(.serverUnreachable))
    }
#endif
