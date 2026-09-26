// TEMPLATE — ViewModifier + extension View pair. Copy, rename, delete this header.
//
// Layer: Presentation/Shared/<Name>Modifier.swift
//
// A `ViewModifier` is for small behaviour applied across many otherwise
// unrelated views: a focus treatment, a toast animation, idle detection. A
// piece of view code with one call site is that view's own body, not a
// modifier.
//
// - The modifier owns the `@FocusState`; the caller gets a `Bool` back
//   through `onFocusChange` and never re-implements `.focusable()`,
//   `.focused()` and `.scaleEffect` by hand.
// - Always paired with an `extension View` convenience. Call sites write
//   `.cardFocusable { isFocused = $0 }`, never `.modifier(CardFocusModifier(...))`.
// - Constants live in a nested enum so the default scale is one number.

import SwiftUI

struct CardFocusModifier: ViewModifier {
    // MARK: - Constants

    enum Constants {
        static let defaultScale: CGFloat = 1.1
        static let animationDuration: TimeInterval = 0.15
    }

    // MARK: - State

    @FocusState private var isFocused: Bool

    // MARK: - Input

    let scale: CGFloat
    let onFocusChange: ((Bool) -> Void)?

    // MARK: - ViewModifier

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            .scaleEffect(isFocused ? scale : 1)
            .animation(.easeInOut(duration: Constants.animationDuration), value: isFocused)
            .onChange(of: isFocused) { _, newValue in
                onFocusChange?(newValue)
            }
    }
}

// MARK: - View convenience

extension View {
    func cardFocusable(
        scale: CGFloat = CardFocusModifier.Constants.defaultScale,
        onFocusChange: ((Bool) -> Void)? = nil
    ) -> some View {
        modifier(CardFocusModifier(scale: scale, onFocusChange: onFocusChange))
    }
}

#if DEBUG
    #Preview {
        HStack(spacing: AppSpacing.regular) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary)
                .frame(width: 184, height: 258)
                .cardFocusable()

            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary)
                .frame(width: 184, height: 258)
                .cardFocusable()
        }
    }
#endif
