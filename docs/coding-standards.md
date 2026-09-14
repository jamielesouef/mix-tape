# Coding Standards — KickTV

These standards reflect the codebase as it exists. Follow these rules when writing or editing code in this project.

---

## Architecture rules

**One type per file.** The file name must exactly match the type name it defines.

**The target is MV: `@MainActor @Observable` services own observable state; Views render it.** A new screen gets a service, not a ViewModel. The 23 `*ViewModel` types already in the tree (11 still `ObservableObject` + `@Published`) are legacy — they stay, and are not mass-migrated. Whichever you're touching, the state container must not import SwiftUI or make layout decisions, and receives dependencies via initialiser parameters (protocol types, not concrete types).

**No SwiftData. No Core Data.** Persistence is `UserDefaults` (lightweight flags) and `Keychain` (auth token). Do not introduce `@Model` or `ModelContainer`.

**Narrow `*RepositoryProtocol` types are the network boundary.** State containers depend only on the repository protocols they need, never on `KickV1API`/`KickV2API` directly. The old `KickClientProtocol`/`KickAPIAdapter` facade was deleted in NAT-1891.

**API clients and WebSocket logic belong in the `APIClient` local SPM package**, not in the main `KickTV` target.

**No actors in production business logic, by convention — but `actor` is required wherever cross-isolation mutable state exists.** This is not optional: any type whose state is mutated from more than one isolation context must be an `actor`, not a lock or an `@unchecked Sendable` class. Today this shows up in concurrency-safe test doubles (e.g. `MockChannelRepository`); the same rule applies to any future production type with the same shape. Off-main work otherwise is done with `async/await` + `Task`, or legacy `DispatchQueue.main.async` in old code paths only.

---

## Swift conventions

**Swift 6 language mode on the app target, `Realtime` and `Diagnostics`; Swift 5 mode on `ChagiLegacy`.** Swift 6 mode checks concurrency completely and unconditionally, so `SWIFT_STRICT_CONCURRENCY` is not set anywhere — there is no second knob.

- New code is written for Swift 6: `Sendable` where a value crosses an isolation boundary, `@MainActor` where it does not.
- `ChagiLegacy` is pinned to `.swiftLanguageMode(.v5)` so the legacy files and the 11 remaining `ObservableObject` ViewModels keep compiling. Its unannotated types are *implicitly* non-`Sendable`, which is why the app target imports it `@preconcurrency` — that import is a self-retiring hatch, not a pattern to copy.
- Do not add `@preconcurrency`, `@unchecked Sendable` or `nonisolated(unsafe)` to code that does not require them. When one is genuinely required, prefer the narrowest: import-level, then the specific type, then the specific global.

**Prefer `async/await` and `Task { }` for new async code.** Reserve `DispatchQueue.main.async` only when editing an existing code path that already uses it.

**`AsyncThrowingStream` and `AsyncStream`** are how repositories stream paginated network results — `LivestreamRepository.getFeaturedLivestreams` is the reference. Follow the same pattern when adding a paginated method.

**No `fatalError`.** Use `throws` and propagate errors instead. Return `nil` only when nil is a valid expected outcome — if nil is unexpected, throw.

**No force cast (`as!`) and no force try (`try!`)** without a comment on the same line explaining why it is safe.

**Logging** — `print()` is blocked by SwiftLint. Use `DataDogLogger.shared` (from `Diagnostics/Sources/Diagnostics/DataDogLogger.swift`) for any logging that needs to appear in production. The SwiftLint `use_of_print` custom rule (severity: error) will fail the build if `print(` appears outside of `Utilities/Sources/Utilities/Console.swift`.

---

## Style

**Australian spelling** in all code, comments, and documentation:

- `colour` not `color`
- `behaviour` not `behavior`
- `capitalisation` not `capitalization`
- `organise` not `organize`

**No inline comments.** Code must be self-explanatory through naming. The only acceptable comments are `// MARK:` section markers and the file header.

**`// MARK: - Section Name`** must be used to delimit logical sections within a file.

**Never change the "Created by" name** in the file header comment.

**SwiftLint** is enforced via `KickTV/.swiftlint.yml`:

| Rule                                  | Value                                                          |
| ------------------------------------- | -------------------------------------------------------------- |
| Line length                           | 150 characters (warning)                                       |
| Type body length                      | 350 (warning) / 400 (error)                                    |
| File length                           | 500 (warning) / 1200 (error)                                   |
| Type name min length                  | 4 characters                                                   |
| `non_optional_string_data_conversion` | Disabled                                                       |
| `use_of_print`                        | Custom rule — error; use `DataDogLogger.shared` instead        |
| Excluded from linting                 | `Models/`, `Configuration/`, `KickClient/MockKickClient.swift` |

---

## Storage

- **Auth token** — stored in Keychain via `KeychainProtocol`. `Keychain`, `KeychainKeys` and `KeychainProtocol` all live in the `Utilities` package; `ChagiLegacy/Sources/ChagiLegacy/Services/AuthService.swift` owns writing the token and `Infrastructure/API/PersistedAuthToken.swift` reads it.
- **Lightweight flags** — `UserDefaults` (e.g. last-fetch timestamp in `HomeViewModel`, app-update payload in `AppConfig`).
- **Images** — SDWebImage cache; never write image data to disk manually.
- **No SwiftData**, no Core Data, no `NSCoding`.

---

## Testing

**Swift Testing for all new unit tests** under `KickTests/SwiftTesting/`. Never use `XCTestCase` for unit tests in new code.

**Every `@Suite` must declare `.tags(...)`.** Use tags from `KickTests/SwiftTesting/Tags.swift`. Add a new tag to that file only if no existing tag fits.

**Every `@Test` must have a string description** that reads as a complete sentence stating the expected behaviour.

**Inject all dependencies via initialiser.** Never access a singleton (`AppConfig.shared`, `DataDogLogger.shared`) inside a test. `CurrentUserSession` has no `.shared` accessor — it is injected through the `@Entry var user` key.

**No `sleep()`, `Task.sleep()`, or arbitrary delays in tests.** Use `confirmation()` (Swift Testing) instead.


**`XCTSkip("reason")`** when a test cannot run without specific infrastructure (e.g. live network, auth token). State the concrete blocker in the reason string.

---

## Detailed idioms (target direction)

The sections below document the target-direction Swift/SwiftUI idioms in detail — how to write code that reads like the rest of the app, not just the architecture rules above.

You will still see `ObservableObject`/`@Published` and untyped `throws` in older files. That is the pre-migration pattern, not an error — see `CLAUDE.md`'s Gap table. Don't rewrite it opportunistically; follow the target-direction idioms below for new code and for files already on the `@Observable` path.

---

## Swift language idioms

### Code shape

Corrections made by hand to Claude-written code (NAT-2610), codified so they aren't repeated.

- Name a function after its effect, not its trigger — `streamBecameVisible(id:)` hid that it starts background work; `prefetchAroundVisibleStream(_:)` says what it does.
- A stateless type reads no ambient global — no `UIDevice.current`, `Bundle.main`, `Locale.current`, `Date()`, `UserDefaults` inside a `Sendable` repository or transport. The composition root reads them and injects a plain `Sendable` value struct (`PlaybackContext` is the reference). This is also what stops a `@MainActor` static hop hiding inside code that must stay off-main.
- Split a transport by job, not by endpoint — URL catalogue (`KickAPI`), pure static `URLRequest` builders (`FeaturedStreamsRequest`), response-status validation (`FeaturedStreamsResponse`), coder config (`FeaturedStreamsCoding`); the transport class itself only sends and logs.
- **One of each of those per app target, not per feature.** The feature-prefixed names above are historical, not a template. Only the DTOs and the `URLRequest` builder are per-boundary; the catalogue, coder, status validator, error enum and the `send`/`logFailure` body are shared, and a second feature adds a `static func` or a case to them. `KickAPIHeadersUseCase` is the reference — one header builder, called from every request builder. Grep `KickTV/Data` and `KickTV/Domain` for the job before declaring a new type that does it, and never fork a shared type under a feature prefix to keep a feature "self-contained".
- An error case names its own failure — add `.playbackUnavailable` rather than throw the nearest-fit `.decoding` for a field that was merely absent.
- A service exposes one derived state, not raw flags for the view to recombine — a `loadState` enum (`.loading`/`.error`/`.empty`/`.loaded`) switched on exhaustively, not `if isLoading, streams.isEmpty { } else if error != nil { }`.
- Structure every type with `// MARK: -`, including one section per protocol it conforms to.
- Comment only what the signature hides — a side effect that outlives the call, an error deliberately not surfaced, an isolation trap. Rationale and history go in the commit message and `docs/failure-log.md`, not a `///` block restating the type or parameters.

### Naming

- **`*Protocol` suffix** for the primary abstraction of a type — `LivestreamRepositoryProtocol`, `KeychainProtocol`.
- **Gerund `*ing`/`*able` form** for capability protocols — `FeaturedStreamsServicing`, `LivestreamPreviewPlaying`, `ProfilePhotoLoading`.
- **`Mock*`** — production-target `DEBUG` doubles with call-count spies, in `Infrastructure/Mocks/`. The types themselves stay `#if DEBUG` (SwiftUI previews and `Environment+Services.swift`'s `@Entry` defaults rely on them), but `AppDependencies`' own factories select a `Mock*` only under `#if TESTING` — see "Compile-time test gating" below.
- **`Stub*`** — test-target doubles in `KickTests/SwiftTesting/Mocks/`. Used in unit tests only. Don't conflate the two.
- **Acronyms stay uppercase**, per Swift API Design Guidelines — `URL`, `VOD`, `HLS`, `API`. `VODPlayerViewModel` is correct. `VodPlaybackRequest` and `playbackUrl` are legacy drift from before this rule was consistently applied — don't propagate that casing into new code, and prefer the uppercase form if you're touching a call site anyway.
- **Booleans read as predicates** — `is`/`can`/`has`/`should` prefixes: `isPlayingVideo`, `canPlayVideo`, `hasError`, `shouldHideGamblingCategory`.
- **Constants** — `static let` in lowerCamelCase for type-scoped constants (`pageSize`, `maxPages`). SCREAMING_SNAKE only for injected build configuration (`DATADOG_CLIENT_TOKEN`, `KICK_HOST_NAME`).

### Optionals & safety

- **No prefix `!` — write `foo == false`.** A leading `!` is easy to miss when skimming and easier still to lose in a diff; `foo == false` reads the same at a glance as `foo == true`. This applies to every negation, including `x.isEmpty == false` and `Task.isCancelled == false`. Enforced by the `no_prefix_negation` custom SwiftLint rule. Force unwraps, `!=`, `try!` and `as!` are untouched by it, and `#if !DEBUG` is exempt because a compilation condition cannot take `== false`.
- **Stacked `guard let … else { return }`** is the standard early-return shape, including cancellation checks: `guard Task.isCancelled == false else { return }` before and after `await` boundaries.
- **Nil-coalescing for defaults** — `config.language ?? languageResolver.resolvedLanguage()`.
- **No force-unwrap in production.** The only `as!` casts in the codebase are unavoidable UIKit/AVFoundation bridging (e.g. casting a `CALayer` to `AVPlayerLayer`), and each one carries a same-line `// swiftlint:disable:this force_cast` plus a comment explaining why it's safe. `fatalError` is reserved for the required `init(coder:)` stub that SwiftUI/UIKit demands but this codebase never calls.
- **`try?`** only where the failure is genuinely ignorable — converting a throwing call into `nil` when nil is already a handled case, not as a shortcut around error handling.

### Error handling

- **One minimal `Error` enum per domain** — `PlaybackError`, `ChannelDetailsServiceError`. Keep cases small and specific; don't create a catch-all `AppError`.
- **Typed throws where exhaustive handling matters** — `PlaybackRepositoryProtocol` declares `throws(PlaybackError)` so every call site gets a compiler-checked exhaustive `catch`:

  ```swift
  protocol PlaybackRepositoryProtocol: Sendable {
      func livePlayback(_ request: LivePlaybackRequest) async throws(PlaybackError) -> PlaybackVideoSource
      func vodPlayback(_ request: VodPlaybackRequest) async throws(PlaybackError) -> PlaybackVideoSource
  }
  ```

- **Return `nil` for "absent but valid"; throw for genuine failure.** No auth token is a valid state (`return nil`), a decoding failure is not (`throw`). Document non-error outcomes explicitly where the distinction isn't obvious — e.g. `PlaybackError.unavailable` is a normal state, not a bug, and is logged at `info`, never `error`.
- **`Result` is confined to test doubles**, used as a configurable outcome resolved with `try result.get()`. Production flow control is `async throws` + `do/catch`.
- **Log-and-continue is the standard ViewModel catch body**: `catch { DataDogLogger.shared.error(error) }`.
- **Never swallow.** An empty `catch {}`, or one that discards the error without logging it, is a bug — either handle it meaningfully, log it, or let it propagate.
- **A failure the viewer can see maps to real copy and a real recovery action.** "Something went wrong" with no way forward is not error handling.

### Enums

- **Associated values for domain modelling**, consumed with binding switches: `case let .category(slug, title):`.
- **Raw value + `CaseIterable` + `Identifiable` + `Sendable`** for UI-facing option sets — feature flags, sort options.
- **Caseless enums as static-only namespaces** — `enum Paginator`, `enum PlaybackErrorMapper` hold only `static` members, never instantiated.
- **Exhaustive switch, no `default`**, grouping cases that share behaviour: `case .server, .network, .decoding:`.

### Access control & immutability

- **`private` by default** for stored dependencies; `@ObservationIgnored private let` for injected collaborators on `@Observable` types (dependencies aren't observable state).
- **`private(set)`** for state that's readable outside the type but only mutable inside it — used heavily for both production published state and test-double call-count spies.
- **`fileprivate`** reserved for SwiftUI modifier/wrapper internals shared within a single file.
- **`public` only at the SPM package boundary** (`APIClient`, `Utilities`, `TypesenseClient`). Nothing in the `KickTV` app target needs to be `public`.
- **`let`-first.** Injected dependencies and config are `let`; `var` only for genuinely mutable observed state.
- **`struct` for values, `final class` for identity** — repositories, adapters, and ViewModels are `final class`; domain models, errors, and loggers are `struct`.
- **Value-semantics collections** where a reference type isn't needed — `OrderedSet` for dedup-with-order, `Set` for membership checks, a `struct` with `mutating` methods instead of a reference buffer.

### Dependency injection

- **Initialiser injection with protocol-typed parameters and concrete defaults**, so production code needs no wiring and tests can substitute a stub:

  ```swift
  init(
      kickClient: KickClientProtocol? = nil,
      preferences: any PreferencesServiceProtocol = PreferencesService()
  ) {
      let resolvedKickClient = kickClient ?? KickAPIAdapter()
      ...
  }
  ```

- **Nil-default-then-resolve** lets one resolved dependency be shared into a second, derived dependency inside the initialiser body, rather than resolving twice.
- **`any` existentials** for stored protocol-typed dependencies (`any PreferencesServiceProtocol`), since these types don't need static dispatch.
- Concrete production types (`KickAPIAdapter`) do their own **constructor composition** — building the repository graph inside their own `init` — so callers only ever depend on the protocol.

---

## Concurrency patterns

- **ViewModels are `@MainActor @Observable final class`.**
- **`async/await` only for new code.** No completion-handler APIs. Bridge legacy completion-handler SDKs with `withCheckedContinuation`, not by adding new completion-handler signatures.
- **`AsyncThrowingStream`/`AsyncStream`** is the pagination/streaming idiom exposed by `KickClientProtocol`. The shared construction lives in `Paginator.stream`, wrapping repeated page fetches into a deduplicated, order-preserving stream:

  ```swift
  static func stream<Element: Hashable & Sendable>(
      maxPages: Int,
      upToLimit: Int,
      fetchPage: @escaping @Sendable (_ page: Int) async throws -> (items: [Element], hasNextPage: Bool)
  ) -> AsyncThrowingStream<[Element], Error> {
      AsyncThrowingStream { callback in
          Task {
              do {
                  var result = OrderedSet<Element>()
                  for page in 1 ... maxPages {
                      let (items, hasNextPage) = try await fetchPage(page)
                      result.append(contentsOf: items)
                      callback.yield(Array(result.prefix(upToLimit)))
                      if result.count >= upToLimit || !hasNextPage { break }
                  }
                  callback.finish()
              } catch {
                  callback.finish(throwing: error)
              }
          }
      }
  }
  ```

  Consume with `for try await page in stream { … }` inside a `do/catch`.
- **`Task { [weak self] in … }`** for fire-and-forget work that must not retain its owner. **`withTaskGroup`** for parallel independent fetches (e.g. fetching several categories concurrently).
- **Cancellation is first-class, not an afterthought.** Store the in-flight `Task` on the owner; cancel it before starting a replacement (e.g. before a new search or reload); checkpoint with `guard !Task.isCancelled else { return }` around `await` boundaries. Never log a cancellation as an error — it's an expected outcome, not a failure.
- **`Sendable`/`actor` discipline is a requirement, not a suggestion.** Value types are `Sendable` by default. `@unchecked Sendable` is only for a documented, specific reason (e.g. a thin wrapper over an SDK that owns its own thread safety) with a same-line comment and, ideally, a ticket to remove it once the underlying type becomes properly `Sendable`. **Any type with cross-isolation mutable state must be an `actor`** — this already applies to concurrency-safe test doubles and applies equally to any future production type with the same shape. Lock primitives (`NSLock`, `os_unfair_lock`, manual synchronisation) are not the answer to a mutable-shared-state problem in this codebase; reach for `actor`.
- **`DispatchQueue.main.async`** is legacy/bridging only — acceptable when extending an existing code path that already uses it, or when a third-party SDK guarantees its callback lands on main and documents that guarantee. Not for new code.

---

## SwiftUI & tvOS idioms

### View composition

- **`body` composes extracted child `View` structs**, each in its own file, wired with plain-value props and closures (`onStreamTapped: { selectedStream = $0 }`) — this is the default way to break up a screen, especially when the region is reused or has its own props.
- **Computed `some View` properties** name a one-off region used only within that one screen (`loggedInView`, `loggedOutView`).
- **`@ViewBuilder` helper functions** are for a region that needs parameters (e.g. a `skeletonRow(count:)` placeholder).
- Rule of thumb: reused or independently-propped → separate `View` struct; one-off named region → computed var; parameterised one-off region → `@ViewBuilder` func.

### View modifiers

- **`ViewModifier` is for small, repeatable behaviour applied across many otherwise-unrelated views** — a toast animation, gamepad input handling, idle detection — never for laying out a single screen or one-off item. If a piece of view code only ever has one call site, it isn't a modifier candidate; it's that view's own body, and belongs inline, in a computed `some View`, or in an extracted child `View` struct (see View composition above).
- **Real examples of the right shape**: the `Toast` animation family — one `ToastModifier` protocol (`showToast: Bool`, `options: ToastOptions?`) with several small conforming types (slide/scale/skew/fade), swapped in based on configuration and attachable to any view that needs a toast; `GamepadViewModifier` (D-pad handling, attachable to any focusable view); `UserInactivityViewModifier` (idle detection, attachable anywhere idle timeout matters). Each earns its `ViewModifier` because it's reused across many different, otherwise-unrelated views — not because it made one view's body shorter.
- **Custom `ViewModifier` struct, paired with an `extension View` convenience method** — never call `.modifier(YourModifier())` directly at the call site; wrap it:

  ```swift
  struct YourModifier: ViewModifier {
      func body(content: Content) -> some View { ... }
  }

  extension View {
      func withYourModifier() -> some View {
          modifier(YourModifier())
      }
  }
  ```

- **Modifier ordering**: content styling → colour/foreground → `.frame` → `.padding` → `.background` → `.contentShape` → focus modifiers (`.focusable()`, `.focused(...)`) → `.scaleEffect` → gesture recognisers → `.onChange`. Layout and appearance first; interaction, focus, and reactions last.

### tvOS focus (read this before any layout change)

tvOS focus is the most fragile part of this app — any layout change can break directional navigation. Test manually on a simulator before merging.

- **`@FocusState` bound to an item's identity, not a boolean**, for any grid or row of selectable items:

  ```swift
  @FocusState private var focusedItemID: String?

  ForEach(items) { item in
      ItemView(item: item)
          .focused($focusedItemID, equals: item.id)
  }
  ```

- **`.focusSection()`** wraps every independently-navigable region (a filter bar, a grid, the side nav) so the focus engine treats it as one directional unit.
- **`@Namespace` + `.focusScope(namespace)`** for a scoped focus region; **`@Environment(\.resetFocus)`** to programmatically move focus back into that scope (e.g. after a screen transition).
- **Restore or set default focus by assigning to the `@FocusState` variable directly.** `prefersDefaultFocus` and `UIFocusGuide` are not used anywhere in this codebase — don't introduce them; follow the imperative `@FocusState` assignment pattern instead, so the behaviour stays consistent with the rest of the app.
- **Focus-driven visual feedback** — scale the focused element up (`scaleEffect` toggled by `@FocusState`/`.onChange`) as the standard "this is focused" affordance; don't invent a new highlight mechanism per component.

### Property wrappers in views

- **`@State` owns the `@Observable` ViewModel**, constructed via the `State(wrappedValue:)` initialiser pattern so a caller-supplied ViewModel (e.g. from a preview) can override the default.
- **`@Environment`** for both system values and custom app-wide values (e.g. the current user session).
- **`@Binding`** for two-way child state — sheet-presentation flags, focus routing passed down from a parent.
- **`@EnvironmentObject` is banned.** It isn't used anywhere in this codebase — don't introduce it; use `@Environment` with a custom key instead.

### Design tokens

- **Fonts and spacing are named tokens in the `Utilities` package**, not raw literals — `Font` extension values and `KickSpacing`-backed `CGFloat` values (`.small`, `.regular`, `.large`, …). Use `.font(.xl)` and `.padding(.leading, .small)`, not a raw point size or number.
- **Colours come from the asset catalogue**, consumed via generated symbols (`.kickBackground`, `.kickRed`), plus a `Color(hex:)` initialiser for one-off values that don't warrant a catalogue entry.
- **Magic-number frames and padding still exist in older views** — treat any raw literal frame/padding value you touch as something to migrate to a token, not a pattern to copy into new code.

### Image loading

- **Always go through the `RemoteImage` view + `RemoteImageLoading` protocol.** Never call `SDWebImageManager` directly from a view — the wrapper is what makes image loading mockable and keeps SDWebImage an implementation detail.

### Previews

- **`#Preview` macro only.** `PreviewProvider` is not used anywhere in this codebase — don't introduce it.
- **Wrap every preview in `#if DEBUG … #endif`.**
- **Use `Mock*` dependencies** (`MockKickClient`, `MockCurrentUserSession`) for VM-backed screens; pass literal or `.constant(...)` values directly for leaf views that don't need a ViewModel.
- **Wrap in `NavigationStack { }`** when the previewed screen relies on navigation modifiers to render correctly.

### Compile-time test gating

- **`#if TESTING`** is a compile-time condition defined only by the `Test` build configuration, which `KickTV-Debug.xcscheme`'s `TestAction` builds under (`LaunchAction`/manual runs stay on `Debug`). Use it for code that must exist only when the unit-test suite runs — the app's own mock-injection factories in `AppDependencies.swift`, the UI-test auth-token bridge in `KickTVApp.swift`, and the `--uitest-*` launch-argument hooks scattered across player/view-model code. A hand-run Debug or QA build never defines `TESTING`, so none of this compiles into it.
- **`#if DEBUG` stays `#if DEBUG`** for anything previews or a hand-run Debug/QA build should still get — `#Preview` blocks, the `Mock*` types themselves, and the `@Entry` defaults in `Kick/Infrastructure/Environment+RealtimeServices.swift`. The `Test` configuration also defines `DEBUG` **for the app target**, so none of this breaks under test.
- **Neither condition reaches a package target.** Xcode gives a package target debug treatment only under the configuration literally named `Debug`; a custom configuration maps to release for packages whatever its own build settings say. Under `Test` a package compiles with `-O`, no `-DDEBUG` and no `-enable-testing`, while the app target still gets `-Onone -DDEBUG -DTESTING`. So `#if DEBUG` inside a package is dead code during the test run, `#if TESTING` never reaches one at all, and `@testable import <Package>` is impossible. **Test-only and debug-only code stays in the app target**, and anything a test touches in a package must be `public`. `.define("DEBUG")` in a manifest is forbidden and CI-guarded.
- **Don't reach for a runtime `ProcessInfo`/`XCTestBundlePath` check** to distinguish "is this a test run" once a compile-time `#if TESTING` branch is available for the call site — compile-time gating means the alternate code path never ships into a shipping or hand-run build at all.

### Navigation

- **Top-level screen switching is a manual `switch` on an enum**, driven by a ViewModel property, wrapped by the `withSideNavigation` modifier — not a `TabView` or `NavigationSplitView`.
- **Feature-internal push navigation uses `NavigationStack` + `.navigationDestination(item:)`**, keyed off an optional `@State` selection that a child view's closure sets.
- **In-feature sheets and overlays use a `@Binding var present…: Bool` flag**, not a `NavigationStack` push.

---

## Performance

Apple TV is memory-constrained and the focus engine must stay at 60fps. A dropped frame during focus movement is far more visible than one during scrolling on a phone.

- **Nothing on the main actor beyond UI updates.** Network calls, JSON decoding, image processing, and sorting or filtering a large collection all belong off it. A `@MainActor` ViewModel `await`s work that runs elsewhere; it doesn't do that work itself.
- **Rails and lists are lazy** — `LazyHStack`/`LazyVStack` inside a `ScrollView`. A plain `HStack` over a paginated feed builds every row up front and is the usual cause of a slow tab switch.
- **No synchronous work in a row's `onAppear`.** It runs during focus-driven scrolling; anything blocking there is a visible stutter.
- **Images are downsampled to display size**, always through `RemoteImage` (never `SDWebImageManager` directly). Full-size decodes of a rail's worth of thumbnails are the usual cause of a jetsam kill on device.
- **No unbounded fetches.** Paginated endpoints use the existing `AsyncThrowingStream<[T], Error>` pattern — `getFeaturedLivestreams` is the reference. Never fetch a whole collection to filter or count it client-side when the endpoint can do it.
- **Deduplicate paginated results.** Overlapping pages produce duplicate cards (NAT-2388); the repository is where that gets fixed, not the view.
- **Do a performance pass at the end of any feature that reads data**, and state what you checked. If a screen got slower, profile it with the `ettrace` skill rather than guessing.

---

## Prohibited patterns (quick reference)

This table covers only the idioms introduced in the detailed sections above — see `CLAUDE.md` for the architecture-level bans (e.g. `ObservableObject` in new code, SwiftData, new singletons).

| Banned | Use instead |
| --- | --- |
| Force-unwrap (`as!`, `try!`) without a same-line comment | `guard let` / `if let` / typed `throws` |
| `Vod`/`Url` camel-case acronym casing in new code | `VOD`/`URL` uppercase, per Swift API Design Guidelines |
| Magic-number frames/padding in new views | `KickSpacing`/`Font` tokens from the `Utilities` package |
| `DispatchQueue.main.async` in new code | `async/await` + `@MainActor` |
| Mutable state shared across isolation contexts without an `actor` | `actor` isolation |
| `PreviewProvider` | `#Preview` macro |
| `@EnvironmentObject` | `@Environment` with a custom key |
| Calling `SDWebImageManager` directly from a view | `RemoteImage` + `RemoteImageLoading` |
| `prefersDefaultFocus`/`UIFocusGuide` | Imperative `@FocusState` assignment |
