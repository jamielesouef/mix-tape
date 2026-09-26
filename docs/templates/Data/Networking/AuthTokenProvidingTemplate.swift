// TEMPLATE — auth token seam. ONE per app. Copy once, delete this header.
//
// Layer: Data/Networking/AuthTokenProviding.swift
//
// A transport asks this for the current token at request-build time. It
// never reads the Keychain or a session object itself; that keeps the
// transport stateless and lets a test inject a fixed token. `nil` means
// "signed out", which is a valid state, so no Authorization header is sent.

protocol AuthTokenProviding: Sendable {
    func currentToken() -> String?
}
