# Swift MV Architecture Template

Generic template. Pulled from trimr project. Use for new iOS/Swift apps.

## Core rule

No ViewModel layer. `@MainActor @Observable` **services** hold state. Views read state through `@Environment`. Views call service methods to act.

## Platform baseline

- iOS 26+, MacOS 26+, tvOS 26+ ONLY. No back-deploy. No `#available` checks.
- Xcode 26, Swift 6.2, Swift 6 language mode.
- Set at project level:
  - `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
  - `SWIFT_APPROACHABLE_CONCURRENCY = NO`
- Use `@concurrent` for real background work only (parsing, decoding, image work).
- Swift Testing for unit tests. XCTest only for UI automation (XCUITest).
- Liquid Glass by default for chrome. Always give a Reduce Transparency fallback.

## Six layers, one direction

```
Presentation → Services → UseCase → Domain
                              ↑
                    Data, Infrastructure
```

| Target | Holds | Depends on |
|---|---|---|
| `AppDomain` | Entities, value types, domain errors, pure business rules | Foundation only |
| `AppUseCase` | One type per use case, repository protocols | `AppDomain` |
| `AppServices` | `@MainActor @Observable` classes — only place state is written | `AppUseCase`, `AppDomain` |
| `AppInfrastructure` | Network client, keychain, logging, third-party SDKs | Foundation, SDKs |
| `AppData` | Repository implementations, DTO-to-Domain mapping | `AppUseCase`, `AppDomain`, `AppInfrastructure` |
| `AppPresentation` | SwiftUI views only | `AppServices`, `AppDomain` |

Rules:
- `AppUseCase` never imports SwiftUI or Observation. Enforce with a build-phase script that greps for those imports and fails the build (`scripts/check-layer-imports.sh` in trimr).
- `AppData` repositories: stateless `Sendable` structs. No caching hidden inside a repository — caching is its own injected collaborator.
- `AppInfrastructure`: stateless or actor-isolated. No plain class with mutable state and no actor.
- Exception: SwiftData `ModelContainer`, `@Model` types, and store actors live in `AppData/Persistence/` — persistence and its repository stay together.
- `AppPresentation`: no use case or repository type in a View's signature. If a view needs data shaped differently, that's the service's job.

## Feature subfolders (not one flat folder per layer)

Inside each layer, group by feature, not by file type:

```
AppServices/<Feature>/
AppUseCase/UseCases/<Feature>/
AppPresentation/Screens/<Feature>/
```

Shared cross-feature code gets its own `Shared/` or `Mocks/` folder per layer.

Presentation components split further by role, not feature:

```
AppPresentation/Components/Cards/
AppPresentation/Components/Chrome/
AppPresentation/Components/Feedback/
AppPresentation/Components/Rows/
AppPresentation/Components/Styles/
```

## Wiring into the environment

Use `@Entry`, not hand-rolled `EnvironmentKey`:

```swift
extension EnvironmentValues {
    @Entry var profileService: ProfileService = .placeholder
}
```

Build the whole object graph once, by hand, at the app root. No DI container, no service locator.

```swift
@main
struct AppRoot: App {
    @State private var profileService = ProfileService(
        fetchProfileUseCase: FetchProfileUseCase(repository: ProfileRepository(client: apiClient))
    )
    var body: some Scene {
        WindowGroup {
            RootView().environment(\.profileService, profileService)
        }
    }
}
```

## Code style rules

- One type per file. Filename matches type name.
- One view per file. No `private var header: some View`, no `@ViewBuilder private func`.
- Every view file has a `#Preview` covering its states (empty, nil, failure included).
- No `fatalError`, `as!`, `try!` without a same-line comment saying why it's unreachable.
- No prefix `!`. Write `x == false`, not `!x`.
- No Combine. `async`/`await`, `AsyncSequence`, `Observation` cover it.
- Constructor injection only. No singletons, no `.shared`, except wrapped system-wide types behind a protocol.
- Protocol suffix: `*Protocol`. Test doubles: `Mock*` (in main target, for previews), `Stub*` (test target only).

## Testing

- Swift Testing only (`@Test`, `@Suite`) for unit tests.
- Tag suites by layer: `.domain`, `.useCase`, `.service`, `.repository`.
- Test behaviour, not the mock's plumbing.
- Every UseCase and Service type gets tests against injected `Mock*`/`Stub*` — never the real `AppData` implementation.
- XCUITest for one happy-path UI test per screen. Drive it off accessibility identifiers, never visible text.

## Commands to verify a new project

```bash
xcodebuild -scheme <App> -destination 'generic/platform=iOS Simulator' -configuration Debug build
xcodebuild test -scheme <App> -destination 'platform=iOS Simulator,name=<Sim>,OS=<Version>'
./scripts/check-layer-imports.sh
swiftformat --lint .
```

## What to copy vs rewrite for a new app

Copy as-is: layer boundaries, the import-check script, `@Entry` wiring pattern, code style rules, testing rules.

Rewrite per app: Domain entities, use cases, service list, screen list — all product-specific.
