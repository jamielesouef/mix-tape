// TEMPLATE — property wrappers and macros. Copy the shape you need, delete this header.
//
// Layer: Presentation/<Feature>/<Name>View.swift
//
// Pick the wrapper by WHO OWNS THE VALUE. Never build a `Binding` by hand to
// avoid choosing.
//
// 1. `@State` — THIS VIEW OWNS IT. Private, initial value inline. Transient
//    UI state: a disclosure, a selection, a draft in a text field.
//    BAD:  `@State var isExpanded: Bool` filled from `init`
//    (only the first init counts; later parent values are silently ignored).
//    BAD:  `@State private var service = ExampleFeatureService(...)`
//    (a service comes from `@Environment`, built once by the composition root).
//
// 2. `@Binding` — THE PARENT OWNS IT, this view edits it. The parent passes
//    `$value`. See Presentation/BindingTemplate.swift.
//    BAD:  a computed `Binding(get:set:)` whose `set` calls a service:
//      private var showsLikeCountsBinding: Binding<Bool> {
//          Binding(
//              get: { service.showsLikeCounts },
//              set: { value in service.setShowsLikeCounts(value) }
//          )
//      }
//    (a hidden mutation that runs on every write, rebuilt on every body pass,
//    and invisible at the call site).
//
// 3. `@State` + `.onChange(of:)` — A CONTROL WHOSE CHANGE IS A SERVICE INTENT.
//    The control binds to this view's `@State`. One `.onChange` mirrors the
//    service into the state (`initial: true` seeds it and picks up changes
//    made elsewhere). A second `.onChange` sends the edit back as an intent.
//    The service's setter is a no-op for an unchanged value, so the two can't
//    loop. This is the replacement for every `Binding(get:set:)` above.
//
// 4. `@Environment` — services and system values. Always `private`.
//    BAD:  `let service: ExampleFeatureService` passed down through `init`
//    (a leaf view gets plain values and closures, never a whole service).
//
// 5. `@Bindable` — only for an `@Observable` model this view was handed to
//    edit in place, such as a draft. Never to write into a service: the
//    service is the sole writer of its state and exposes intents.
//
// 6. `@FocusState` — private, owned by the view that has the fields. Several
//    fields share one optional enum, not one `Bool` per field.
//
// 7. `@AppStorage` / `@SceneStorage` — not in a view. Machine-local settings
//    go through the service that owns `UserDefaults`, so they can be
//    injected and tested, and the storage choice lives in one place.
//    BAD:  `@AppStorage("showsLikeCounts") private var showsLikeCounts = true`
//
// MACROS
//
// - `@Observable` goes on a `@MainActor final class *Service`, or on a draft
//   model handed to `@Bindable`. Never `ObservableObject` / `@Published`.
// - `@ObservationIgnored` on a stored property of an `@Observable` type
//   that must not trigger view updates, such as a cache no view reads.
// - `@Entry` for environment keys only. See EnvironmentKeyTemplate.swift.
// - `#Preview` inside `#if DEBUG`. A view that takes a `@Binding` is
//   previewed with `@Previewable @State`, never `.constant(...)`, so the
//   control actually works in the canvas.
//
// MEMBER ORDER: Constants -> @Environment -> @State/@FocusState -> @Binding -> private let -> let/var -> body ->
//   subviews -> helpers

import SwiftUI

struct ExampleFeatureSettingsView: View {
    // MARK: - Environment

    @Environment(\.exampleFeatureService) private var service

    // MARK: - State

    @State private var showsLikeCounts = true
    @State private var isShowingAdvanced = false

    // MARK: - View

    var body: some View {
        Form {
            ExampleFeatureSettingRow(
                isOn: $showsLikeCounts,
                title: String(localized: "example_feature_shows_like_counts"),
                detail: String(localized: "example_feature_shows_like_counts_detail")
            )

            DisclosureGroup(String(localized: "example_feature_advanced"), isExpanded: $isShowingAdvanced) {
                Text(String(localized: "example_feature_advanced_detail"))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: service.showsLikeCounts, initial: true) {
            showsLikeCounts = service.showsLikeCounts
        }
        .onChange(of: showsLikeCounts) {
            service.setShowsLikeCounts(showsLikeCounts)
        }
    }
}

#if DEBUG
    #Preview("Like counts on") {
        ExampleFeatureSettingsView()
            .environment(
                \.exampleFeatureService,
                ExampleFeatureService(repository: MockExampleFeatureRepository())
            )
    }

    #Preview("Like counts off") {
        let service = ExampleFeatureService(repository: MockExampleFeatureRepository())
        service.setShowsLikeCounts(false)

        return ExampleFeatureSettingsView()
            .environment(\.exampleFeatureService, service)
    }
#endif
