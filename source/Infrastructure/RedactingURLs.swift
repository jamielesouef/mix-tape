//  RedactingURLs.swift
//  mixtape
//
//  Created by Jamie Le Souëf on 07/09/2026.
//

import Foundation

nonisolated func redactingURLs(_ message: String) -> String {
    message.replacing(/https?:\/\/\S+/, with: "<url>")
}
