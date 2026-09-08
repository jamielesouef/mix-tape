//  PlatformCardButton+tvOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(tvOS)
    import SwiftUI

    extension View {
        /// The button style for a focusable card in a shared screen: `.card` lifts and shadows the
        /// focused card, which is what makes a shelf navigable from the Siri Remote.
        func platformCardButtonStyle() -> some View {
            buttonStyle(.card)
        }
    }
#endif
