// TEMPLATE — @Entry environment key. Copy, rename, delete this header.
//
// Layer: Infrastructure/Extensions/Environment+<Feature>.swift
//
// ONE shape. A concrete `@Observable` service gets an `@Entry` key whose
// default is the REAL implementation, built by the composition root.
//
// - The default is hoisted into a `private let` so every read of the key
//   returns the same instance. An `@Entry` default expression is evaluated
//   per read; inlining the constructor there would build a new service each
//   time. A test should assert `first === second` across two reads.
// - `MainActor.assumeIsolated` is required because the service is
//   `@MainActor` and a global initialiser is not. It is safe because the
//   first read comes from SwiftUI's environment, on the main actor. Do not
//   read this key from a background task.
// - Never a `#if DEBUG` mock default. A missing injection must be visible in
//   the build every developer runs. A preview injects its own:
//   `.environment(\.exampleFeatureService, ExampleFeatureService(repository: MockExampleFeatureRepository()))`
// - Views read it as `@Environment(\.exampleFeatureService) private var service`.

import SwiftUI

private let defaultExampleFeatureService = MainActor.assumeIsolated {
    AppDependencies.makeExampleFeatureService()
}

extension EnvironmentValues {
    @Entry var exampleFeatureService: ExampleFeatureService = defaultExampleFeatureService
}
