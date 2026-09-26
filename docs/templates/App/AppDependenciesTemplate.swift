// TEMPLATE — composition root. Copy once, delete this header.
//
// Layer: App/AppDependencies.swift
//
// The one place the real object graph is built, and the ONE place ambient
// globals (`Locale.current`, `Bundle.main`) are read. Everything below it
// receives plain values and protocols.
//
// - `#if TESTING` is a compile condition defined ONLY by the test build
//   configuration (add `TESTING` to `SWIFT_ACTIVE_COMPILATION_CONDITIONS` for
//   that configuration and no other). Under it the factory returns the
//   `Mock*` so the unit-test host never hits the network. Never gate a mock
//   on `#if DEBUG`: that puts the fake in the build every developer runs and
//   hides a missing injection until release.
// - The service factory is `@MainActor` because the service is.
// - The token provider here is the signed-out default. The real app wraps
//   its auth layer's token read in `ClosureAuthTokenProvider { ... }`.

import Foundation

enum AppDependencies {
    // MARK: - Services

    @MainActor
    static func makeExampleFeatureService() -> ExampleFeatureService {
        ExampleFeatureService(repository: makeExampleFeatureRepository())
    }

    // MARK: - Private

    private static func makeExampleFeatureRepository() -> any ExampleFeatureRepositoryProtocol {
        #if TESTING
            return MockExampleFeatureRepository()
        #else
            return ExampleFeatureRepository(
                transport: ExampleFeatureHTTPTransport(tokenProvider: ClosureAuthTokenProvider.noToken),
                context: makeExampleFeatureContext()
            )
        #endif
    }

    private static func makeExampleFeatureContext() -> ExampleFeatureContext {
        ExampleFeatureContext(
            languageCode: Locale.current.language.languageCode?.identifier ?? "en"
        )
    }
}
