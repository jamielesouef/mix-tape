# Layer Templates

Reference `.swift` files showing the shape of new code in each layer of a
Swift 6 / SwiftUI app. They are project-agnostic: the `Example*` and `App*`
names are placeholders, and nothing here points at a real project file. Copy
the closest template before writing a new file, rename, delete the header
notes, and keep the body.

**They are not built by any target.** They do typecheck as a unit, so every
type one template references exists in another. If you change a signature,
change every template that calls it.

## Toolchain floor

| Needs | For |
| --- | --- |
| Swift 6.2+ | `@concurrent` on the shared `send`, `throws(E)` typed throws, `#expect(throws:)` |
| OS 18+ (iOS, tvOS, macOS 15) | `Mutex` in the test stub `URLProtocol` |
| tvOS or macOS | `.onMoveCommand` in the screen template and the move-direction mapping. Drop both on iOS |

## Which template to copy

| Layer | Template | Copy it when you're adding |
| --- | --- | --- |
| Any | `FunctionsTemplate.swift` | any function. Pure, optional-returning, typed-throwing, async throwing |
| Any | `ControlFlowTemplate.swift` | stacked guards, an `if` chain that is fine, an `if` chain that should be a `switch`, exhaustive `switch`, `switch` as an expression |
| Domain | `Domain/DomainModelTemplate.swift` | a pure value type for a feature |
| Domain | `Domain/DomainErrorTemplate.swift` | a feature's `Error` enum |
| Domain | `Domain/UseCaseTemplate.swift` + `Domain/ExampleMoveDirectionTemplate.swift` | a decision a view makes: focus, ordering, filtering, which state to render |
| Data, shared | `Data/Networking/*` | **once per app.** The URL catalogue, coder config, error protocol, status validation, decode, the one `send`, and the token provider. A feature adds a `static func` or a case here. It never forks a copy |
| Data, per feature | `Data/DTOTemplate.swift`, `Data/ResponseEnvelopeDTOTemplate.swift` | wire-format types for one endpoint |
| Data, per feature | `Data/RequestTemplate.swift` | the pure static `URLRequest` builder |
| Data, per feature | `Data/HTTPTransportProtocolTemplate.swift` + `Data/TransportTemplate.swift` | the thin class that builds a request and calls the shared `send` |
| Data, per feature | `Data/ContextTemplate.swift` | the `Sendable` value the composition root fills from ambient globals |
| Data, per feature | `Data/RepositoryProtocolTemplate.swift` + `Data/RepositoryTemplate.swift` | the boundary a service calls through; maps DTO to domain |
| Services | `Services/SingleFlightRefreshingTemplate.swift` | **once per app.** Cancel-and-replace refresh, shared by every service |
| Services | `Services/ServiceTemplate.swift` | a screen's state and intents. MV, not MVVM |
| Infrastructure | `Infrastructure/MockTemplate.swift` | the app-target double previews and the test build use |
| App | `App/AppDependenciesTemplate.swift` | the composition root: builds the real graph, substitutes mocks under the test-only flag |
| Presentation | `Presentation/EnvironmentKeyTemplate.swift` | wiring a service into `@Environment` |
| Presentation | `Presentation/ScreenTemplate.swift` | a screen: `.task` starts the service, `switch loadState` renders it |
| Presentation | `Presentation/ViewTemplate.swift` | a leaf view with props and an action closure |
| Presentation | `Presentation/PropertyWrappersTemplate.swift` | choosing `@State`, `@Binding`, `@Environment`, `@Bindable`, `@FocusState`, and the `@Observable` / `@Entry` / `#Preview` macros. A control whose change is a service intent: `@State` + `.onChange(of:)`, never `Binding(get:set:)` |
| Presentation | `Presentation/BindingTemplate.swift` | a leaf view that edits a value its parent owns, previewed with `@Previewable @State` |
| Presentation | `Presentation/ViewModifierTemplate.swift` | behaviour reused across unrelated views, as a `ViewModifier` + `extension View` pair |
| Presentation | `Presentation/MoveCommandMappingTemplate.swift` | mapping a SwiftUI-only value to the domain's own enum at the view boundary |
| Utilities | `Utilities/SharedConstantsTemplate.swift`, `Utilities/LogTemplate.swift` | **once per app.** Design tokens and the one logging call |
| Tests | [`unittests/`](unittests/README.md) | every test-target file |

## The rules the templates encode

These are the rules. A template that disagrees with this list is wrong; fix the
template.

### Architecture

1. **MV, not MVVM.** A `@MainActor @Observable final class *Service` is the
   only writer of observable state. Views read it through `@Environment` and
   call its methods. `class *ViewModel`, `ObservableObject` and `@Published`
   do not appear in new code.
2. **Layers: Domain ← Data ← Services ← Presentation.** Domain imports no
   SwiftUI. A repository is stateless, `Sendable`, and never `@MainActor`.
3. **A decision a view makes is a use case.** Which element focuses next,
   whether a button is enabled, which state to render, how a list is ordered.
   It lives in `Domain/<Feature>/UseCase/*UseCase.swift` as an `enum` of
   `static func`s and is unit-tested. If you can't test a branch without
   launching the app, it is still in the view.
4. **A service exposes one derived state.** A `loadState` enum switched on
   exhaustively, derived with a `switch` over a tuple of the raw flags. Never
   raw `isLoading`/`error`/`items` for the view to recombine.
5. **One shared networking stack per app.** Only the DTOs, the `*Request`
   builder and the `*HTTPTransport` are per feature. The catalogue, coder,
   error protocol, validate, decode and `send` exist once. Adding a feature
   adds a `static func` or a case to them.

### Concurrency

6. **Swift Concurrency only.** No Combine, no `DispatchQueue`, no completion
   handlers where an `async` overload exists.
7. **Network and decode never run on the main actor.** `send` is
   `@concurrent`. A repository or transport is never annotated `@MainActor`
   to silence an isolation error. Only the final assignment of finished state
   happens on the main actor, inside the service.
8. **Cancellation is checked around every `await`.** Fetch into a local,
   `guard Task.isCancelled == false`, then assign. A superseded task must never
   overwrite a newer result. Cancel-and-replace lives once, in
   `SingleFlightRefreshing`; a service conforms to it.
9. **Sendable by inference.** Do not write `: Sendable` on a non-public value
   type whose stored properties are all `Sendable`. Write it on protocols, on
   `final class` types, on `public` cross-module types that are not
   `@frozen`, and when vouching with `@unchecked`.

### Errors

10. **One minimal `Error` enum per feature**, conforming to the shared
    `APIError` protocol when it crosses the shared send path. A case names
    its own failure. Add `.itemUnavailable` rather than throwing the
    nearest-fit `.decoding` for a field that was merely absent.
11. **Typed throws at every boundary** so each call site gets an exhaustive
    `catch`. Return `nil` only for "genuinely absent". Throw for failure.

### Code shape

12. **No comments in a body.** Only the file header, `// MARK: -` markers and
    tool directives. What a comment would have said goes in a name, the
    commit message, or the project's error log. The header notes in these
    templates are deleted on copy.
13. **One type per file**, filename matches the type. Structure every type
    with `// MARK: -`, one section per protocol it conforms to.
14. **No prefix `!`**. Write `foo == false`. `#if !DEBUG` is the one exception.
15. **Exhaustive `switch`, no `default`.** Group cases that share behaviour.
    Adding a case must be a compile error at every switch until handled.
16. **No ambient globals in a stateless type.** No `Locale.current`,
    `Bundle.main`, `Date()`, `UserDefaults` inside a repository, transport or
    use case. The composition root reads them once and injects a plain
    `Sendable` value struct.
17. **User-facing copy is `String(localized:)`**, never a literal in a view or
    a `switch`.
18. **Design tokens, not literals.** Spacing from `AppSpacing`. Fonts and
    colours from the system's semantic styles (`.title3`, `.secondary`) until
    the design system diverges; then one shared token enum, never a raw point
    size or hex value in a view.

19. **A multi-line declaration ends its own paragraph.** Consecutive one-line
    `let`s stay grouped. Once a declaration wraps, leave a blank line between
    its closing `)` and the next `let` or `var`, so each wrapped call reads as
    one block. `App/AppDependencies.swift` is the reference.
    ```swift
    let fileManager = FileManager.default
    let defaults = UserDefaults.standard

    let localStore = UserDefaultsLocalSettingsStore(
        defaults: defaults,
        defaultSettings: makeDefaultLocalSettings(resolver)
    )

    let sharedStore = makeSharedStore()
    ```

### Views

20. **Member order**, each in its own `// MARK: -` section:
    `private enum Constants` → `@Environment` → `@State` / `@FocusState` →
    `@Binding` → `private let` dependencies → `let` / `var` inputs and
    closures → `body` → subviews → helpers.
21. **A view holds no logic.** It reads service state, calls a use case, and
    applies the result. No computed `Binding(get:set:)`. Pick the wrapper by
    who owns the value: `@State` if this view does, `@Binding` if the parent
    does. A change that is a service intent binds to `@State` and is sent
    from `.onChange(of:)`. No `@AppStorage` in a view; machine-local settings
    go through their service.
22. **Every view ships a `#Preview` inside `#if DEBUG`**, with the empty,
    long-text and no-image variants, not only the happy path.
23. **One `@Entry` shape.** A concrete `@Observable` service gets an `@Entry`
    key whose default is the real implementation, hoisted into a
    `private let` so every read returns the same instance. A preview injects
    its own with `.environment(\.key, ...)`. Never a `#if DEBUG` mock default.

### Test doubles

24. **`Mock*` lives in the app target**, wrapped in `#if DEBUG`, for previews
    and for the composition root under `#if TESTING`. `Stub*` lives in the
    test target. Don't conflate them.
25. **A mock is substituted only under `#if TESTING`**, a compile condition
    your test build configuration defines and no other configuration does.
    `#if DEBUG` returning a mock puts a fake in the build every developer
    runs, so a missing injection stays invisible until release.
