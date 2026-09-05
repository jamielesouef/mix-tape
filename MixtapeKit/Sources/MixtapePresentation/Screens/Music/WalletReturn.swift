//  WalletReturn.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import MixtapeDomain

/// What a wallet can do for a finished album (engineering doc §9.1 "putting it back", slice 015):
/// honour the return on the page the album sits on, or page the library in further first. Pure and
/// platform-shared so the decision is testable without the iOS-only view.
///
/// Ownership is not decided here. Measured on iOS 26.5: a `NavigationStack` root covered by a pushed
/// destination is not updated, so a wallet whose detail is up cannot see the finish at all — the
/// pushed detail pops itself, and the wallet that is on screen when the event arrives, or the first
/// one to appear afterwards, claims the return through `MusicPlayerService.claimFinish(albumID:)`.
nonisolated enum WalletReturn: Equatable {
    /// The album is on `page`: page there, pulse the sleeve, acknowledge.
    case honour(page: Int)
    /// The loaded albums do not include it yet: page the library in further and wait. The event
    /// stays unacknowledged until a wallet can honour it.
    case pageIn

    init(finished albumID: String, pager: WalletPager) {
        self = pager.page(of: albumID).map { .honour(page: $0) } ?? .pageIn
    }
}
