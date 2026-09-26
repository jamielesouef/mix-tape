# Unit Test Templates

Reference `.swift` files for the test target. Companion to
[`../README.md`](../README.md), which covers production code. Project-agnostic:
the app module is called `ExampleApp` here, so every file starts with
`@testable import ExampleApp`. Replace it with your module name.

**Not built by any target**, but they typecheck against the production
templates, so a signature change on one side breaks the other. Keep them in
step.

## Which template to copy

| Layer | Template | Copy it when you're testing |
| --- | --- | --- |
| Support | `Support/TagsTemplate.swift` | **once per test target.** The tag catalogue every `@Suite` draws from |
| Fixtures | `Fixtures/PayloadFixturesTemplate.swift` | a hand-written wire-format JSON fixture shared by the DTO and transport suites |
| Domain | `Domain/UseCaseTestTemplate.swift` | a pure `enum` use case. No stub, parameterised over inputs |
| Data | `Data/DTOTestTemplate.swift` | a DTO's decode plus `toDomain()`, through the production decoder, against the fixture |
| Data | `Data/StubURLProtocolTemplate.swift` | the marker-keyed `URLProtocol` a transport suite stubs through |
| Data | `Data/HTTPTransportTestTemplate.swift` | request shape, status-code mapping, decode. Pairs with the stub above |
| Services | `Services/StubRepositoryTemplate.swift` | the `actor` stub a service test injects: configurable `Result`, call count, and a gate for in-flight tests |
| Services | `Services/ServiceTestTemplate.swift` | a `@MainActor @Observable` service's `loadState` across load, empty, error, idempotency and supersession |

## The rules the templates encode

1. **Swift Testing only.** `@Suite("Name", .tags(...))`, `@Test("sentence")`.
   Never `XCTestCase` for a unit test.
2. **A `@Test` is `async` when it awaits and `throws` when it uses `try`.**
   Nothing more: the formatter (`redundantThrows`, `redundantAsync`) strips
   an unused effect marker, so a test declares the effects its body has.
   Adding an `await` later means adding `async` then, which the compiler
   points at.
3. **Every `@Test` has a description that reads as a sentence** stating the
   behaviour, not the function name restated.
4. **Tags come from one catalogue** (`Support/TagsTemplate.swift`). Add a tag
   there only when nothing fits.
5. **No `sleep`, no `Task.sleep`, no polling loop.** A service's entry
   points are `async` and awaited, so a test awaits `start()` or `refresh()`
   and asserts. Waiting on something in flight goes through a
   continuation-backed gate on the stub (`StubRepositoryTemplate.swift`),
   never a yield-and-retry loop.
6. **Never `@MainActor` on a `@Test`, never `.serialized`.** Read
   main-actor state with `await sut.loadState`. If you reach for either,
   you have shared state to remove.
7. **`Stub*` for every test-target double.** An `actor` when it records
   calls or holds a configurable result. A `struct` when it is a pure
   fixed-value stub. `Mock*` is the app-target name; don't reuse it here.
8. **Inject everything through the initialiser.** No singleton inside a
   test. No `URLSession.shared`, no `UserDefaults.standard`.
9. **Decode fixtures with the production decoder** (`APICoding.makeDecoder()`).
   A test that builds its own decoder can pass while the app rejects the
   same payload.
10. **Assert derivations, not pass-throughs.** A service test asserts the
    `loadState` the service derived (`.empty` from `[]`, `.error` from a
    failure), and the call count on the stub. It never asserts the stub's
    own fixture came back unchanged.
11. **`#expect(throws:)` for a typed-throws call**, never `do/catch` with a
    manual `Issue.record`. `HTTPTransportTestTemplate.swift` shows it against
    the transport.
12. **The stub `URLProtocol` is the one lock in the test target.**
    `URLProtocol`'s entry points are synchronous class methods, so an actor
    is impossible there. `Mutex` (OS 18+) guards a registry keyed by a
    per-test marker header, which is what lets the suite run in parallel.
    Every other double is an actor.

## What these templates don't cover

- XCUITest UI tests. Different framework, different process, different rules.
- App-target `Mock*` doubles and the `#if TESTING` factory. See
  `../Infrastructure/MockTemplate.swift` and `../App/AppDependenciesTemplate.swift`.
