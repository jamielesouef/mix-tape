// TEMPLATE — injected context value. Copy, rename, delete this header.
//
// Layer: Data/<Feature>/<Name>Context.swift
//
// A stateless type reads no ambient global. `Locale.current`, `Bundle.main`,
// `UIDevice.current`, `Date()` and `UserDefaults` are read ONCE, at the
// composition root (App/AppDependenciesTemplate.swift), and handed to the
// repository as this plain value. That is what keeps the repository
// `Sendable` and off the main actor, and what lets a test pass a fixed
// language without touching the process's locale.
// `Sendable` is inferred. Add fields as endpoints need them.

struct ExampleFeatureContext {
    let languageCode: String
}
