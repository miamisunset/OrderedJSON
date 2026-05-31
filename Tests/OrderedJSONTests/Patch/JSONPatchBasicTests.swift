import Testing

@testable import OrderedJSON

@Suite("JSONPatch basic tests")
struct JSONPatchBasicTests {
  @Test("patch add to object") func patchAddToObject() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/baz"),
        "value": JSON.string("qux"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "foo": JSON.string("bar"),
      "baz": JSON.string("qux"),
    ])
    #expect(result == expected)
  }

  @Test("patch add to array") func patchAddToArray() throws {
    let json = JSON.array([JSON.string("a"), JSON.string("b")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/1"),
        "value": JSON.string("c"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.array([JSON.string("a"), JSON.string("c"), JSON.string("b")])
    #expect(result == expected)
  }

  @Test("patch add append to array") func patchAddAppendToArray() throws {
    let json = JSON.array([JSON.string("a"), JSON.string("b")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/-"),
        "value": JSON.string("c"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.array([JSON.string("a"), JSON.string("b"), JSON.string("c")])
    #expect(result == expected)
  }

  @Test("patch remove from object") func patchRemoveFromObject() throws {
    let json = JSON.object([
      "foo": JSON.string("bar"),
      "baz": JSON.string("qux"),
    ])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("remove"),
        "path": JSON.string("/baz"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object(["foo": JSON.string("bar")])
    #expect(result == expected)
  }

  @Test("patch remove from array") func patchRemoveFromArray() throws {
    let json = JSON.array([JSON.string("a"), JSON.string("b"), JSON.string("c")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("remove"),
        "path": JSON.string("/1"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.array([JSON.string("a"), JSON.string("c")])
    #expect(result == expected)
  }

  @Test("patch replace value") func patchReplaceValue() throws {
    let json = JSON.object([
      "foo": JSON.string("bar")
    ])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("replace"),
        "path": JSON.string("/foo"),
        "value": JSON.number(.integer(42)),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object(["foo": JSON.number(.integer(42))])
    #expect(result == expected)
  }

  @Test("patch copy value") func patchCopyValue() throws {
    let json = JSON.object([
      "foo": JSON.string("bar")
    ])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("copy"),
        "from": JSON.string("/foo"),
        "path": JSON.string("/baz"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "foo": JSON.string("bar"),
      "baz": JSON.string("bar"),
    ])
    #expect(result == expected)
  }

  @Test("patch move value") func patchMoveValue() throws {
    let json = JSON.object([
      "foo": JSON.string("bar"),
      "baz": JSON.string("qux"),
    ])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("move"),
        "from": JSON.string("/baz"),
        "path": JSON.string("/foo"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "foo": JSON.string("qux")
    ])
    #expect(result == expected)
  }

  @Test("patch test pass") func patchTestPass() throws {
    let json = JSON.object([
      "foo": JSON.string("bar")
    ])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("test"),
        "path": JSON.string("/foo"),
        "value": JSON.string("bar"),
      ])
    ])
    let result = try json.applying(patch)
    #expect(result == json)
  }

  @Test("patch in place mutates") func patchInPlaceMutates() throws {
    var json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/baz"),
        "value": JSON.string("qux"),
      ])
    ])
    try json.patch(patch)
    let expected = JSON.object([
      "foo": JSON.string("bar"),
      "baz": JSON.string("qux"),
    ])
    #expect(json == expected)
  }
}
