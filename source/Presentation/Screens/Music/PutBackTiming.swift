//  PutBackTiming.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 14/09/2026.
//

import SwiftUI

/// The sleeve is slid back into the wallet, then its border pulses so the eye lands on where
/// the album went. Each wait in `WalletScreen` waits out the animation that precedes it.
enum PutBackTiming {
    static let pageTurnSettle = 0.6
    static let pulseFade = 0.15
    static let pulseHold = 0.4
    static let pulseAnimation = Animation.easeInOut(duration: pulseFade)
}
