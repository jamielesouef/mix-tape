//  SignInFlow+tvOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

#if os(tvOS)
    import MixtapeServices
    import SwiftUI

    /// tvOS: server entry, then Quick Connect first with password sign-in as the secondary action
    /// (engineering doc §9, tvOS table).
    struct SignInFlow: View {
        @Environment(\.sessionService) private var sessionService
        @State private var usingPassword = false

        var body: some View {
            if sessionService.serverIdentity == nil {
                ServerEntryScreen()
            } else if usingPassword {
                SignInScreen(onUseQuickConnect: {
                    usingPassword = false
                })
            } else {
                QuickConnectScreen(
                    onCancel: { sessionService.cancelQuickConnect() },
                    onUsePassword: {
                        sessionService.cancelQuickConnect()
                        usingPassword = true
                    },
                )
            }
        }
    }

    #Preview("server entry") {
        SignInFlow().environment(\.sessionService, MockSessionService.signedOut())
    }

    #Preview("quick connect") {
        SignInFlow().environment(\.sessionService, MockSessionService.quickConnectWaiting())
    }

    #Preview("failure") {
        SignInFlow().environment(\.sessionService, MockSessionService.failed(.serverUnreachable))
    }
#endif
