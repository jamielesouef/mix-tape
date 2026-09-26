// TEMPLATE — View-logic use case. Copy, rename, delete this header.
//
// Layer: Domain/<Feature>/UseCase/<Name>UseCase.swift
//
// A decision a VIEW makes is a use case, not a closure body: which element
// takes focus next, whether a button is enabled, which of several states to
// render, how a list is ordered or filtered. If you can't unit-test the
// branch without launching the app, it is still stuck in the view.
//
// Shape:
// - `enum` with `static func` members only. No stored state, no instance,
//   no protocol, no injection. A pure function of its arguments.
// - No SwiftUI import. When a rule reacts to a SwiftUI-only value
//   (MoveCommandDirection, ScenePhase), define the domain's own enum in its
//   own file (ExampleMoveDirectionTemplate.swift) and map at the view
//   boundary (Presentation/MoveCommandMappingTemplate.swift).
// - The view keeps only the wiring: read state, call the use case, apply
//   the result. `guard let next = SomeUseCase.nextIndex(...) else { return }`
//   is the whole handler.
// - PURE. No logging, no writes, no `Date()` or `Locale.current` inside.
//   Same inputs, same output, every time.
// - OPTIONAL MEANS "GENUINELY ABSENT", NEVER "FAILED". `nextIndex` returns
//   `nil` at the end of the list because there legitimately is no next
//   index. A failure is a typed `throws`, see FunctionsTemplate.swift.
// - Exhaustive `switch`, no `default`. The two `where` cases fall through to
//   a final case that names both members, so adding a direction is a compile
//   error here.
// - `clamped` is the rule for "the list changed under a remembered index".
//   Small, but it is a decision, so it is here and tested, not inline in
//   the screen.
// - Test in the test target's Domain/ folder (unittests/Domain/UseCaseTestTemplate.swift).

enum ExampleFeatureFocusUseCase {
    static func nextIndex(current: Int, count: Int, moved: ExampleMoveDirection) -> Int? {
        guard count > 0 else {
            return nil
        }

        switch moved {
        case .forward where current + 1 < count:
            return current + 1
        case .backward where current > 0:
            return current - 1
        case .forward,
             .backward:
            return nil
        }
    }

    static func clamped(_ index: Int, count: Int) -> Int {
        guard count > 0 else {
            return 0
        }

        return min(max(index, 0), count - 1)
    }
}
