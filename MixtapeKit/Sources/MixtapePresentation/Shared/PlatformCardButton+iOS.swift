//  PlatformCardButton+iOS.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 04/09/2026.
//

#if os(iOS)
    import SwiftUI

    extension View {
        func platformCardButtonStyle() -> some View {
            buttonStyle(.plain)
        }
    }
#endif
