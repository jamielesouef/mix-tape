//  SignInScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

public struct SignInScreen: View {
    @Environment(\.sessionService) private var sessionService
    @State private var userName = ""
    @State private var password = ""
    let onUseQuickConnect: () -> Void

    public init(onUseQuickConnect: @escaping () -> Void) {
        self.onUseQuickConnect = onUseQuickConnect
    }

    public var body: some View {
        VStack(spacing: 20) {
            Text(sessionService.serverIdentity?.name ?? "Sign in")
                .font(.largeTitle.bold())
            TextField("Username", text: $userName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier(SignInIdentifiers.userNameField)
            SecureField("Password", text: $password)
                .onSubmit { signIn() }
                .accessibilityIdentifier(SignInIdentifiers.passwordField)
            if let error = sessionService.error {
                Text(error.message)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(SignInIdentifiers.errorLabel)
            }
            Button("Sign In") { signIn() }
                .buttonStyle(.borderedProminent)
                .disabled(userName.isEmpty || sessionService.isBusy)
                .accessibilityIdentifier(SignInIdentifiers.signInButton)
            Button("Use Quick Connect", action: onUseQuickConnect)
                .accessibilityIdentifier(SignInIdentifiers.quickConnectButton)
            Button("Change server") { sessionService.clearServer() }
                .disabled(sessionService.isBusy)
                .accessibilityIdentifier(SignInIdentifiers.changeServerButton)
            if sessionService.isBusy {
                ProgressView()
            }
        }
        .padding(32)
        .frame(maxWidth: 480)
    }

    private func signIn() {
        let name = userName
        let secret = password
        Task { await sessionService.signIn(userName: name, password: secret) }
    }
}

#if DEBUG
    #Preview("loaded") {
        SignInScreen(onUseQuickConnect: {}).environment(\.sessionService, MockSessionService.serverValidated())
    }

    #Preview("failure") {
        SignInScreen(onUseQuickConnect: {})
            .environment(\.sessionService, MockSessionService.signInFailed(.invalidCredentials))
    }

    #Preview("empty") {
        SignInScreen(onUseQuickConnect: {}).environment(\.sessionService, MockSessionService.signedOut())
    }
#endif
