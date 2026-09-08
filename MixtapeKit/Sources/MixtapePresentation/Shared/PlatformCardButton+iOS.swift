//  PlatformCardButton+iOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(iOS)
    import SwiftUI

    extension View {
        /// The button style for a tappable card in a shared screen: plain on iOS, `.card` on tvOS
        /// where a focus effect is what makes the card navigable at all.
        func platformCardButtonStyle() -> some View {
            buttonStyle(.plain)
        }
    }
#endif
