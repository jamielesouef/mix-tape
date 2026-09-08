//  RedactingURLs.swift
//  MixtapeInfrastructure
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

/// Replaces every `http://…` / `https://…` run in `message` with `<url>` (slice 019, codex High #3).
/// Stream URLs carry `ApiKey` and `deviceId`, and libVLC repeats the whole media resource locator
/// in its warnings, so nothing URL-shaped may reach a `.public` log. Pure and `nonisolated`: libVLC
/// calls its logger from its own thread.
public nonisolated func redactingURLs(_ message: String) -> String {
    message.replacing(/https?:\/\/\S+/, with: "<url>")
}
