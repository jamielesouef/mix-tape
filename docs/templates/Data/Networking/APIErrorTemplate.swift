// TEMPLATE — shared API error protocol. ONE per app. Copy once, delete this header.
//
// Layer: Data/Networking/APIError.swift
//
// Every feature error that crosses the shared send/validate/decode path
// conforms to this, so `HTTPSending.send` and `APIResponseHandling` can
// throw the feature's own typed error without knowing the feature. The
// static requirements are satisfied by plain enum cases of the same name.
//
// `Error` already implies `Sendable`. `Equatable` is required so tests and
// `LoadState` can compare errors.

protocol APIError: Error, Equatable {
    static var network: Self { get }
    static var server: Self { get }
    static var decoding: Self { get }
    static var encoding: Self { get }
    static var unauthorised: Self { get }
    static var forbidden: Self { get }
    static var notFound: Self { get }
}
