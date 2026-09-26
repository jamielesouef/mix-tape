// TEMPLATE — app-wide design token. ONE set per app. Copy once, delete this header.
//
// Layer: Presentation/Shared/AppSpacing.swift (or Utilities/ for a non-visual constant)
//
// STOP. Check reuse first. This layer is ONE set of shared things for the
// whole app, not a per-feature dumping ground. Grep for the job before
// writing a new type here; a second copy under a feature prefix is the
// violation.
//
// - Caseless enum as a static-only namespace. Never instantiated.
// - No stored state. If it needs state it is a Service, not a token.
// - Reads no ambient global (`Bundle.main`, `Locale.current`, `Date()`).
// - Views use `AppSpacing.regular`, never a raw number. Fonts and colours
//   use the system's semantic styles (`.title3`, `.secondary`) until the
//   design system diverges; then `AppFont` / `AppColour` here, same shape.

import Foundation

enum AppSpacing {
    static let xsmall: CGFloat = 8
    static let small: CGFloat = 16
    static let regular: CGFloat = 32
}
