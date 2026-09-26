// TEMPLATE — closure-backed token provider. ONE per app. Copy once, delete this header.
//
// Layer: Data/Networking/ClosureAuthTokenProvider.swift
//
// The smallest real `AuthTokenProviding`. The composition root wraps the
// auth layer's token read in the closure; a test passes `{ "stub-token" }`
// or `{ nil }`. `noToken` is the default for environment keys and previews.
// `Sendable` is inferred: the only stored property is a `@Sendable` closure.

struct ClosureAuthTokenProvider: AuthTokenProviding {
    // MARK: - Defaults

    static let noToken = ClosureAuthTokenProvider { nil }

    // MARK: - Private

    private let resolve: @Sendable () -> String?

    // MARK: - Init

    init(resolve: @escaping @Sendable () -> String?) {
        self.resolve = resolve
    }

    // MARK: - AuthTokenProviding

    func currentToken() -> String? {
        resolve()
    }
}
