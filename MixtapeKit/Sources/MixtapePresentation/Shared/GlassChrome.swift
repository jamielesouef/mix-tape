//  GlassChrome.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

/// Liquid Glass for chrome, with the Reduce Transparency fallback to an opaque surface
/// (engineering doc §9 "Chrome"). Every glass surface in the app goes through this modifier.
struct GlassChrome: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(.background, in: .rect(cornerRadius: cornerRadius))
        } else {
            content.glassEffect(in: .rect(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    func glassChrome(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassChrome(cornerRadius: cornerRadius))
    }
}
