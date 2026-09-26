// TEMPLATE — wire-format fixtures. Copy, rename, delete this header.
//
// Layer: <TestTarget>/Fixtures/<Feature>PayloadFixtures.swift
//
// - Hand-written JSON in the API's real convention (snake_case, envelope,
//   nested objects). Never a Swift literal built from the DTO's own
//   initialiser; if the fixture doesn't decode, the DTO is wrong.
// - One fixture, two suites: the DTO test decodes it directly and the
//   transport test serves it through the stub. If the wire shape changes,
//   one edit.
// - The second item omits every optional field on purpose, so the "defaults
//   when absent" test has a real payload to decode.
// - Caseless enum, `static let` strings. No state.

enum ExampleFeaturePayloadFixtures {
    static let items = """
    {
        "data": [
            {
                "id": "a",
                "title": "Morning news",
                "like_count": 12345,
                "thumbnail": { "src": "https://example.com/thumb.jpg" },
                "owner_id": 42
            },
            {
                "id": "b",
                "owner_id": 43
            }
        ],
        "message": "OK"
    }
    """
}
