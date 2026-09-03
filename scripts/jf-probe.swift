#!/usr/bin/env swift
//  jf-probe.swift
//  scripts
//
//  Created by Jamie Le Souëf on 03/09/2026.
//
//  Server-observable acceptance checks go through this script (SPEC-DECISIONS.md
//  decision 47). Usage: ./scripts/jf-probe.swift [METHOD] /Sessions [json-body]
//  Reads JELLYFIN_BASE_URL and JELLYFIN_API_KEY from the gitignored
//  .jellyfin-dev.env at the repository root (decision 45). Prints the HTTP status
//  on the first line and the response body after it. Never prints the token.

import Foundation

var arguments = CommandLine.arguments
var method = "GET"
var body: String?
if arguments.count >= 3, arguments[1].uppercased() == arguments[1] {
    method = arguments.remove(at: 1).uppercased()
}

if arguments.count == 3 {
    body = arguments.remove(at: 2)
}

guard arguments.count == 2 else {
    print("usage: jf-probe.swift [METHOD] </server/path?query> [json-body]")
    exit(2)
}

let scriptDirectory = URL(fileURLWithPath: arguments[0]).deletingLastPathComponent()
let envURL = scriptDirectory.appendingPathComponent("../.jellyfin-dev.env").standardizedFileURL
guard let envText = try? String(contentsOf: envURL, encoding: .utf8) else {
    print("cannot read \(envURL.path)")
    exit(2)
}

var env: [String: String] = [:]
for rawLine in envText.split(separator: "\n") {
    let line = rawLine.trimmingCharacters(in: .whitespaces)
    if line.isEmpty || line.hasPrefix("#") {
        continue
    }
    guard let equals = line.firstIndex(of: "=") else { continue }
    let key = String(line[..<equals]).trimmingCharacters(in: .whitespaces)
    let value = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
    env[key] = value
}

guard let baseURL = env["JELLYFIN_BASE_URL"], baseURL.isEmpty == false else {
    print("JELLYFIN_BASE_URL missing from .jellyfin-dev.env")
    exit(2)
}

guard let token = env["JELLYFIN_API_KEY"], token.isEmpty == false else {
    print("JELLYFIN_API_KEY missing from .jellyfin-dev.env")
    exit(2)
}

guard let url = URL(string: baseURL + arguments[1]) else {
    print("cannot form a URL from \(baseURL) and \(arguments[1])")
    exit(2)
}

var request = URLRequest(url: url)
request.httpMethod = method
request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
if let body {
    request.httpBody = Data(body.utf8)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
}

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let error {
        print("transport error: \(error.localizedDescription)")
        exit(1)
    }
    guard let http = response as? HTTPURLResponse else {
        print("no HTTP response")
        exit(1)
    }
    print(http.statusCode)
    if let data, let body = String(data: data, encoding: .utf8) {
        print(body)
    }
    exit(0)
}

task.resume()
dispatchMain()
