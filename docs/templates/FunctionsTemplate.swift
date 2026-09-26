// TEMPLATE — function shapes. Copy the shape you need, delete this header.
//
// Applies across every layer. Four shapes. Pick the narrowest one that is
// true of the function; don't make something `async throws` "to be safe"
// when it is pure.
//
// 1. PURE. Reads its parameters, returns a value. No logging, no mutation,
//    no ambient global (`Date()`, `Locale.current`, `UserDefaults`) inside.
//    Same inputs, same output. The default shape for a use case.
//    BAD:  `AppLog.info("resolving"); return isSignedIn == false && Date() > cutoff`
//    (a side effect and an ambient read hiding in a "pure" function).
//
// 2. OPTIONAL RETURN, for "genuinely absent", never for "failed". `nil`
//    means there legitimately is no value for these inputs. Every caller
//    can `guard let` / `??` it without needing to know why.
//    BAD:  `static func rank(_ raw: String) -> Int? { Int(raw) }`
//    (`nil` for bad input is indistinguishable from `nil` for "no rank").
//
// 3. TYPED THROWS, SYNC. A genuine failure the caller must handle.
//    `throws(SomeError)` gives every call site an exhaustive `catch`.
//    Encoding goes through the shared `APICoding.makeEncoder()`, never a
//    bare `JSONEncoder()`.
//    BAD:  `guard let payload = try? JSONEncoder().encode(body) else { return nil }`
//    (swallows the failure behind `nil`, and forks the coder config).
//
// 4. ASYNC THROWING. Network and decode work. Typed throws, never a
//    completion handler, never `@MainActor`. The await happens off the main
//    actor so a decode never blocks the UI.
//    BAD:  `@MainActor static func fetchItems(...) async throws -> [Item]`
//    (untyped, and annotated `@MainActor` to "fix" an isolation error, which
//    drags the request and decode onto the main thread).

import Foundation

enum ExampleFunctionShapes {
    // MARK: - 1. Pure

    static func isCompactLayout(itemCount: Int, threshold: Int) -> Bool {
        itemCount <= threshold
    }

    // MARK: - 2. Optional return

    static func rank(at index: Int, isRanked: Bool) -> Int? {
        isRanked ? index + 1 : nil
    }

    // MARK: - 3. Typed throws, sync

    static func makeRequest(url: URL, body: some Encodable) throws(ExampleFeatureError) -> URLRequest {
        let payload: Data
        do {
            payload = try APICoding.makeEncoder().encode(body)
        } catch {
            throw .encoding
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = payload
        return request
    }

    // MARK: - 4. Async throwing

    static func fetchItems(
        language: String,
        transport: any ExampleFeatureHTTPTransportProtocol
    ) async throws(ExampleFeatureError) -> [ExampleFeatureItem] {
        let response = try await transport.fetchItems(language: language)
        return response.data.map { $0.toDomain() }
    }
}
