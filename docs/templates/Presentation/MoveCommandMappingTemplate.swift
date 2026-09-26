// TEMPLATE — SwiftUI value -> domain enum, at the view boundary. Copy, rename, delete this header.
//
// Layer: Presentation/Shared/MoveCommandDirection+ExampleMoveDirection.swift
//
// Domain imports no SwiftUI, so the use case takes `ExampleMoveDirection`.
// This extension is the whole mapping, in Presentation/, as real code a
// screen can call: `direction.exampleMoveDirection`.
//
// - `nil` for the directions this feature doesn't page on. That is a
//   genuinely absent value, not a failure.
// - `@unknown default` is the one sanctioned `default`: `MoveCommandDirection`
//   is a non-frozen library enum, so the compiler requires it. A `switch`
//   over one of YOUR enums never has one.
// - `.onMoveCommand` exists on tvOS and macOS. Drop this file on iOS.

import SwiftUI

extension MoveCommandDirection {
    var exampleMoveDirection: ExampleMoveDirection? {
        switch self {
        case .right:
            .forward
        case .left:
            .backward
        case .up,
             .down:
            nil
        @unknown default:
            nil
        }
    }
}
