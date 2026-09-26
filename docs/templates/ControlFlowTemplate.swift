// TEMPLATE — control flow. Copy the shape you need, delete this header.
//
// Applies across every layer. Five shapes.
//
// 1. STACKED GUARD. The early-return shape for preconditions and unwrapping,
//    including cancellation checks around `await`. Each guard is independent;
//    hitting any one ends the function.
//
// 2. INDEPENDENT EARLY-RETURN `if` CHAIN. This one is FINE. Each `if` is its
//    own terminal rule over a different, unrelated condition, and any one is
//    enough to decide. There is no shared state space, so there is nothing
//    to `switch` over. Don't "fix" it.
//
// 3. WHEN AN `if` CHAIN IS THE SMELL. Several `if`s reading the SAME small
//    set of flags to derive ONE value. Each condition depends on the others
//    having fallen through, so reading case 3 means holding cases 1 and 2 in
//    your head:
//      if isLoading, items.isEmpty { return .loading }
//      if let error, items.isEmpty { return .error(error) }
//      if items.isEmpty { return .empty }
//      return .loaded(items)
//    A `switch` over a tuple of the same flags puts each case's FULL
//    precondition on its own line and the compiler checks exhaustiveness.
//    It returns an ENUM, because a caller will branch on it again. `String`
//    is for a value that is genuinely text.
//
// 4. EXHAUSTIVE SWITCH, NO `default`. Every case named, cases that share
//    behaviour grouped. Adding a case is a compile error at every switch
//    until it is handled. User-facing copy is `String(localized:)`, never a
//    literal.
//
// 5. `switch` AS AN EXPRESSION. The switch IS the value, assigned to a `let`.
//    No `var` plus an assignment in every case. Wrapped after the `=` per
//    the formatter's multiline-conditional-assignment rule.

import Foundation

enum ExampleControlFlow {
    // MARK: - Types

    enum State {
        case loading
        case error
        case empty
        case loaded
    }

    enum LogLevel {
        case error
        case info
    }

    // MARK: - 1. Stacked guard

    static func firstResolvedURL(for id: String, resolved: [String: URL], isCancelled: Bool) -> URL? {
        guard isCancelled == false, let url = resolved[id] else {
            return nil
        }

        return url
    }

    // MARK: - 2. Independent early-return if chain

    static func isVisible(slug: String, hidesRestricted: Bool, isRestrictedSlug: Bool) -> Bool {
        if hidesRestricted, isRestrictedSlug, slug.isEmpty {
            return false
        }

        return true
    }

    // MARK: - 3. Derive one state with a tuple switch

    static func loadState(isLoading: Bool, error: ExampleFeatureError?, isEmpty: Bool) -> State {
        switch (isLoading, error, isEmpty) {
        case (true, _, true):
            .loading
        case (_, .some, true):
            .error
        case (_, nil, true):
            .empty
        case (_, _, false):
            .loaded
        }
    }

    // MARK: - 4. Exhaustive switch, no default

    static func message(for error: ExampleFeatureError) -> String {
        switch error {
        case .network,
             .server:
            String(localized: "error_connection")
        case .decoding,
             .encoding:
            String(localized: "error_unexpected_response")
        case .unauthorised,
             .forbidden:
            String(localized: "error_not_allowed")
        case .notFound,
             .itemUnavailable:
            String(localized: "error_not_found")
        }
    }

    // MARK: - 5. switch as an expression

    static func logLevel(for error: ExampleFeatureError) -> LogLevel {
        switch error {
        case .network,
             .server,
             .unauthorised,
             .forbidden,
             .notFound,
             .itemUnavailable:
            .info
        case .decoding,
             .encoding:
            .error
        }
    }
}
