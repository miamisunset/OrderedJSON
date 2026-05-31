import Testing

@testable import OrderedJSON

@Suite("JSONPatch path escaping tests")
struct JSONPatchPathEscapingTests {
  @Test("path ~0 unescapes to ~") func pathTildeZero() throws {
    let json = JSON.object(["foo~bar": .string("value")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("test"),
        "path": .string("/foo~0bar"),
        "value": .string("value"),
      ])
    ])
    let result = try json.applying(patch)
    #expect(result == json)
  }

  @Test("path ~1 unescapes to /") func pathTildeOne() throws {
    let json = JSON.object(["foo/bar": .string("value")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("test"),
        "path": .string("/foo~1bar"),
        "value": .string("value"),
      ])
    ])
    let result = try json.applying(patch)
    #expect(result == json)
  }

  @Test("path ~01 unescapes to ~1 (order: ~1 first, then ~0)") func pathTildeZeroOne() throws {
    // Key is "~1". Escaped: ~ → ~0 → "~01", then / → ~1 → stays "~01"
    // Unescape: ~1 → / → no match, ~0 → ~ → "~01" → "~1"
    let json = JSON.object(["~1": .string("value")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("test"),
        "path": .string("/~01"),
        "value": .string("value"),
      ])
    ])
    let result = try json.applying(patch)
    #expect(result == json)
  }

  @Test("path ~10 unescapes to /0 (order: ~1 first, then ~0)") func pathTildeOneZero() throws {
    // Key is "/0". Escaped: ~ → ~0 → stays (no ~), / → ~1 → "~10"
    // Unescape: ~1 → / → "~10" → "/0", ~0 → ~ → stays "/0"
    let json = JSON.object(["/0": .string("value")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("test"),
        "path": .string("/~10"),
        "value": .string("value"),
      ])
    ])
    let result = try json.applying(patch)
    #expect(result == json)
  }

  @Test("path with multiple ~0 and ~1 segments") func pathMultipleEscapes() throws {
    let json = JSON.object(["a~b/c": .string("value")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("test"),
        "path": .string("/a~0b~1c"),
        "value": .string("value"),
      ])
    ])
    let result = try json.applying(patch)
    #expect(result == json)
  }
}
