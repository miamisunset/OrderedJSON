import Testing

@testable import OrderedJSON

@Suite("JSONPatch move/copy tests")
struct JSONPatchMoveCopyTests {
  @Test("move overlapping: source contains target path") func moveOverlappingSourceContainsTarget()
    throws
  {
    let json = JSON.object(["a": .string("value")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("move"),
        "from": .string("/a"),
        "path": .string("/b"),
      ])
    ])
    let result = try json.applying(patch)
    // Remove /a, then add value at /b
    let expected = JSON.object(["b": .string("value")])
    #expect(result == expected)
  }

  @Test("move where source and target are same path") func moveSamePath() throws {
    let json = JSON.object(["a": .string("value")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("move"),
        "from": .string("/a"),
        "path": .string("/a"),
      ])
    ])
    let result = try json.applying(patch)
    // Per RFC: remove is no-op (source==target), add replaces
    #expect(result == json)
  }

  @Test("move nested value") func moveNested() throws {
    let json = JSON.object([
      "a": JSON.object(["b": .string("nested")]),
      "c": .number(.integer(1)),
    ])
    let patch = JSON.array([
      JSON.object([
        "op": .string("move"),
        "from": .string("/a/b"),
        "path": .string("/d"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "a": JSON.object([:]),
      "c": .number(.integer(1)),
      "d": .string("nested"),
    ])
    #expect(result == expected)
  }

  @Test("move from array to object") func moveArrayToObject() throws {
    let json = JSON.object([
      "arr": JSON.array([.string("a"), .string("b")]),
      "target": .null,
    ])
    let patch = JSON.array([
      JSON.object([
        "op": .string("move"),
        "from": .string("/arr/0"),
        "path": .string("/target"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "arr": JSON.array([.string("b")]),
      "target": .string("a"),
    ])
    #expect(result == expected)
  }

  @Test("move from object to array") func moveObjectToArray() throws {
    let json = JSON.object([
      "source": .string("value"),
      "arr": JSON.array([.string("a")]),
    ])
    let patch = JSON.array([
      JSON.object([
        "op": .string("move"),
        "from": .string("/source"),
        "path": .string("/arr/1"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "arr": JSON.array([.string("a"), .string("value")])
    ])
    #expect(result == expected)
  }

  @Test("copy where source and target are same path (should be no-op)") func copySamePath() throws {
    let json = JSON.object(["a": .string("value")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("copy"),
        "from": .string("/a"),
        "path": .string("/a"),
      ])
    ])
    let result = try json.applying(patch)
    // Per RFC: copy from same path to same path should be no-op
    #expect(result == json)
  }

  @Test("copy from nested path") func copyFromNested() throws {
    let json = JSON.object([
      "a": JSON.object(["b": .string("nested")])
    ])
    let patch = JSON.array([
      JSON.object([
        "op": .string("copy"),
        "from": .string("/a/b"),
        "path": .string("/c"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "a": JSON.object(["b": .string("nested")]),
      "c": .string("nested"),
    ])
    #expect(result == expected)
  }

  @Test("copy from root to nested path") func copyFromRoot() throws {
    let json = JSON.object(["foo": .string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("copy"),
        "from": .string(""),
        "path": .string("/copy"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "foo": .string("bar"),
      "copy": JSON.object(["foo": .string("bar")]),
    ])
    #expect(result == expected)
  }

  @Test("copy from array element") func copyFromArrayElement() throws {
    let json = JSON.object([
      "arr": JSON.array([.string("a"), .string("b"), .string("c")])
    ])
    let patch = JSON.array([
      JSON.object([
        "op": .string("copy"),
        "from": .string("/arr/1"),
        "path": .string("/arr/-"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "arr": JSON.array([.string("a"), .string("b"), .string("c"), .string("b")])
    ])
    #expect(result == expected)
  }
}
