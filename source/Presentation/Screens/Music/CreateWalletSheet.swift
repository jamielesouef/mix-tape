//  CreateWalletSheet.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

import Foundation
import SwiftUI

struct CreateWalletSheet: View {
    // MARK: - Properties

    @Environment(\.walletsService) private var walletsService: WalletsService
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    // MARK: - Initialization

    init() {}

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                TextField("Wallet Name", text: $name)
                    .accessibilityIdentifier(WalletsHomeIdentifiers.createWalletButton + ".nameField")
            }
            .navigationTitle("New Wallet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

                        guard trimmed.isEmpty == false else {
                            return
                        }

                        Task {
                            await walletsService.createWallet(name: trimmed)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("loaded") {
        CreateWalletSheet().environment(\.walletsService, MockWalletsService.loaded())
    }

    #Preview("empty") {
        CreateWalletSheet().environment(\.walletsService, MockWalletsService.empty())
    }

    #Preview("failure") {
        CreateWalletSheet().environment(\.walletsService, MockWalletsService.failed())
    }
#endif
