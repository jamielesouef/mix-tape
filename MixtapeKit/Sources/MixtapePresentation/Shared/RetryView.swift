//  RetryView.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import MixtapeDomain
import SwiftUI

struct RetryView: View {
    let error: MixtapeError
    let retry: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't load", systemImage: "wifi.exclamationmark")
        } description: {
            Text(error.message)
                .accessibilityIdentifier(RetryIdentifiers.messageLabel)
        } actions: {
            Button("Retry") { Task { await retry() } }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(RetryIdentifiers.retryButton)
        }
    }
}

#if DEBUG
    #Preview("loaded") {
        RetryView(error: .serverUnreachable) {}
    }

    #Preview("empty") {
        RetryView(error: .transport("")) {}
    }

    #Preview("failure") {
        RetryView(error: .sessionExpired) {}
    }
#endif
