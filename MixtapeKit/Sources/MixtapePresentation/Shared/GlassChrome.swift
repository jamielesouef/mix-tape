//  GlassChrome.swift
//  MixtapePresentation
//
//  Created by Jamie Le Souëf on 03/09/2026.
//

import SwiftUI

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
