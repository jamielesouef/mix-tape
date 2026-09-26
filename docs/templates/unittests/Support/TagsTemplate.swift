// TEMPLATE — tag catalogue. ONE per test target. Copy once, delete this header.
//
// Layer: <TestTarget>/Support/Tags.swift
//
// Every `@Suite` declares `.tags(...)` from this list, so a filtered run
// (`--filter-tag domain`) means the same thing everywhere. Add a tag here
// only when nothing existing fits; a tag per suite defeats the point.

import Testing

extension Tag {
    @Tag static var domain: Self
    @Tag static var data: Self
    @Tag static var networking: Self
    @Tag static var service: Self
}
