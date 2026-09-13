//  WalletReturn.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

import MixtapeDomain

nonisolated enum WalletReturn: Equatable {
    case honour(page: Int)
    case pageIn

    init(finished albumID: String, pager: WalletPager) {
        self = pager.page(of: albumID).map { .honour(page: $0) } ?? .pageIn
    }
}
