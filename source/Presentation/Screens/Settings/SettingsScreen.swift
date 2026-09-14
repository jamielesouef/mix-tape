//  SettingsScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

struct SettingsScreen: View {
    // MARK: - Properties

    @Environment(\.sessionService) private var sessionService: SessionService

    init() {}

    // MARK: - Body

    var body: some View {
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

    // MARK: - Private

    private var userName: String {
        sessionService.currentSession?.userName ?? "—"
    }

    private var serverHost: String {
        sessionService.currentSession?.serverURL.host() ?? "—"
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        SettingsScreen().environment(\.sessionService, MockSessionService.signedIn())
    }

    #Preview("empty") {
        SettingsScreen().environment(\.sessionService, MockSessionService.signedOut())
    }

    #Preview("failure") {
        SettingsScreen().environment(\.sessionService, MockSessionService.failed(.sessionExpired))
    }
#endif
