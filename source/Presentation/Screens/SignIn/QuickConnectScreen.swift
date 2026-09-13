//  QuickConnectScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

public struct QuickConnectScreen: View {
    @Environment(\.sessionService) private var sessionService
    let onCancel: () -> Void
    let onUsePassword: (() -> Void)?

    public init(onCancel: @escaping () -> Void, onUsePassword: (() -> Void)? = nil) {
        self.onCancel = onCancel
        self.onUsePassword = onUsePassword
    }

    public var body: some View {
        VStack(spacing: 24) {
            Text("Quick Connect")
                .font(.largeTitle.bold())
            switch sessionService.quickConnect {
            case .idle:
                ProgressView("Requesting a code…")
            case let .waiting(code):
                Text(code)
                    .font(.system(size: 64, weight: .bold, design: .monospaced))
                    .accessibilityIdentifier(QuickConnectIdentifiers.codeLabel)
                Text("In Jellyfin, open Settings → Quick Connect and enter this code.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                ProgressView("Waiting for approval…")
            case let .failed(error):
                Text(error.message)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(QuickConnectIdentifiers.errorLabel)
                Button("Try Again") { Task { await sessionService.startQuickConnect() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(QuickConnectIdentifiers.retryButton)
            }
            if let onUsePassword {
                Button("Sign in with a password", action: onUsePassword)
                    .accessibilityIdentifier(QuickConnectIdentifiers.passwordButton)
            }
            Button("Cancel", action: onCancel)
                .accessibilityIdentifier(QuickConnectIdentifiers.cancelButton)
        }
        .padding(32)
        .frame(maxWidth: 600)
        .task {
            if sessionService.quickConnect == .idle {
                await sessionService.startQuickConnect()
            }
        }
    }
}

#if DEBUG
    #Preview("waiting") {
        QuickConnectScreen(onCancel: {}).environment(\.sessionService, MockSessionService.quickConnectWaiting())
    }

    #Preview("failure") {
        QuickConnectScreen(onCancel: {}, onUsePassword: {})
            .environment(\.sessionService, MockSessionService.quickConnectFailed(.quickConnectUnavailable))
    }

    #Preview("idle") {
        QuickConnectScreen(onCancel: {}).environment(\.sessionService, MockSessionService.serverValidated())
    }
#endif
