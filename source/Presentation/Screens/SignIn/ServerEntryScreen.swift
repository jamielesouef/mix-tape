//  ServerEntryScreen.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

struct ServerEntryScreen: View {
    // MARK: - Properties

    @Environment(\.sessionService) private var sessionService: SessionService
    @State private var urlText = ""

    init() {}

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Text("mixtape")
                .font(.largeTitle.bold())
            Text("Enter your Jellyfin server address")
                .foregroundStyle(.secondary)
            TextField("localhost:8096", text: $urlText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { connect() }
                .accessibilityIdentifier(ServerEntryIdentifiers.urlField)
            if let error = sessionService.error {
                Text(error.message)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(ServerEntryIdentifiers.errorLabel)
            }
            Button("Connect") { connect() }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.isEmpty || sessionService.isBusy)
                .accessibilityIdentifier(ServerEntryIdentifiers.connectButton)
            if sessionService.isBusy {
                ProgressView()
            }
        }
        .padding(32)
        .frame(maxWidth: 480)
    }

    // MARK: - Private

    private func connect() {
        let text = urlText

        Task { await sessionService.validateServer(urlText: text) }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("empty") {
        ServerEntryScreen().environment(\.sessionService, MockSessionService.signedOut())
    }

    #Preview("failure") {
        ServerEntryScreen().environment(
            \.sessionService,
            MockSessionService.failed(.notAJellyfinServer)
        )
    }

    #Preview("loaded") {
        ServerEntryScreen().environment(\.sessionService, MockSessionService.serverValidated())
    }
#endif
