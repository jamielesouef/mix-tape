//  WalletFooter.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

import SwiftUI

/// The status line under the wallet's pager: a spinner while the first page loads, the failure
/// and its retry, the empty notice, or which page of the wallet is open.
struct WalletFooter: View {
    let phase: ContentPhase<Page<MediaItem>>
    let pageIndex: Int
    let pageCount: Int
    let retry: () -> Void

    var body: some View {
        switch phase {
        case .loading:
            ProgressView()
                .controlSize(.small)
        case let .failed(error):
            Text(error.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
                .accessibilityIdentifier(WalletIdentifiers.retryButton)
        case .empty:
            Text("No albums in this library yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(WalletIdentifiers.emptyLabel)
        case .loaded:
            Text("Page \(pageIndex + 1, format: .number) of \(pageCount, format: .number)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(WalletIdentifiers.pageIndicator)
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        VStack {
            WalletFooter(
                phase: .loaded(Page(items: MockMedia.albums, totalCount: 5, startIndex: 0)),
                pageIndex: 0,
                pageCount: 3,
                retry: {}
            )
        }
    }

    #Preview("loading — no page yet") {
        VStack {
            WalletFooter(phase: .loading, pageIndex: 0, pageCount: 0, retry: {})
        }
    }

    #Preview("empty") {
        VStack {
            WalletFooter(phase: .empty, pageIndex: 0, pageCount: 1, retry: {})
        }
    }

    #Preview("failure") {
        VStack {
            WalletFooter(phase: .failed(.serverUnreachable), pageIndex: 0, pageCount: 1, retry: {})
        }
    }
#endif
