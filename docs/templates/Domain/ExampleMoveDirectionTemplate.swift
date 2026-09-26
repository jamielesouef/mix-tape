// TEMPLATE — Domain's own enum for a SwiftUI-only value. Copy, rename, delete this header.
//
// Layer: Domain/<Feature>/<Name>.swift
//
// Domain imports no SwiftUI. When a use case reacts to a SwiftUI value such
// as MoveCommandDirection or ScenePhase, define the domain's own enum here
// and map SwiftUI -> this enum at the view boundary. The mapping is real
// code, not a comment: Presentation/MoveCommandMappingTemplate.swift.

enum ExampleMoveDirection {
    case forward
    case backward
}
