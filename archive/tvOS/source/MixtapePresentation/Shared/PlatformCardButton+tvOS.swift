//  PlatformCardButton+tvOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(tvOS)
    import SwiftUI

    extension View {
        func platformCardButtonStyle() -> some View {
            buttonStyle(.card)
        }
    }
#endif
