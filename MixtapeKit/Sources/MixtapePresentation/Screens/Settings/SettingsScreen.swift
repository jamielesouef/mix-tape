//  SettingsScreen.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeServices
import SwiftUI

public struct SettingsScreen: View {
    @Environment(\.sessionService) private var sessionService

    public init() {}

    public var body: some View {
        List {
            Section("Server") {
                LabeledContent("Name", value: sessionService.serverIdentity?.name ?? serverHost)
                    .accessibilityIdentifier(SettingsIdentifiers.serverNameLabel)
                LabeledContent("User", value: userName)
                    .accessibilityIdentifier(SettingsIdentifiers.userNameLabel)
            }
            Section {
                Button("Sign Out", role: .destructive) { sessionService.signOut() }
                    .accessibilityIdentifier(SettingsIdentifiers.signOutButton)
            }
        }
    }

    private var userName: String {
        if case let .signedIn(session) = sessionService.state {
            return session.userName
        }
        return "—"
    }

    private var serverHost: String {
        if case let .signedIn(session) = sessionService.state {
            return session.serverURL.host() ?? "—"
        }
        return "—"
    }
}

#Preview("loaded") {
    SettingsScreen().environment(\.sessionService, MockSessionService.signedIn())
}

#Preview("empty") {
    SettingsScreen().environment(\.sessionService, MockSessionService.signedOut())
}

#Preview("failure") {
    SettingsScreen().environment(\.sessionService, MockSessionService.failed(.sessionExpired))
}
