//  Wallet.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 28/09/2026.
//

struct Wallet: Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: WalletKind
    let albumIDs: [String]

    init(id: String, name: String, kind: WalletKind, albumIDs: [String] = []) {
        self.id = id
        self.name = name
        self.kind = kind
        self.albumIDs = albumIDs
    }

    /// Personal wallets are the only kind a listener can rename, delete, or add albums to.
    var isEditable: Bool {
        kind == .personal
    }
}
