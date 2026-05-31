import Testing

@testable import OrderedJSON

@Suite("JSONPatch append marker tests")
struct JSONPatchAppendMarkerTests {
  @Test("add to array at index equal to count appends") func addAtIndexEqualToCount() throws {
    let json = JSON.array([.string("a"), .string("b")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/2"),
        "value": .string("c"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.array([.string("a"), .string("b"), .string("c")])
    #expect(result == expected)
  }

  @Test("add to array at index greater than count errors") func addAtIndexGreaterThanCount() {
    let json = JSON.array([.string("a"), .string("b")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/5"),
        "value": .string("c"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Array index out of bounds for add"))
  }

  @Test("add with '-' on empty array appends") func addDashEmptyArray() throws {
    let json = JSON.array([])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/-"),
        "value": .string("first"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.array([.string("first")])
    #expect(result == expected)
  }

  @Test("add with '-' on object errors") func addDashOnObject() {
    let json = JSON.object(["foo": .string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/foo/-"),
        "value": .string("x"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    // First segment "foo" resolves to string "bar", then "-" segment checks for array
    #expect(error == .formatError("Cannot append to non-array"))
  }

  @Test("remove with '-' errors (no remove semantics for '-')") func removeWithDash() {
    let json = JSON.array([.string("a"), .string("b")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("remove"),
        "path": .string("/-"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    // `-` is not a valid integer index, so it's rejected as non-array index
    #expect(error == .formatError("Cannot index into non-array for remove"))
  }

  @Test("replace with '-' errors (no replace semantics for '-')") func replaceWithDash() {
    let json = JSON.array([.string("a"), .string("b")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("replace"),
        "path": .string("/-"),
        "value": .string("x"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("'-' append marker is only valid for add operations"))
  }
}
