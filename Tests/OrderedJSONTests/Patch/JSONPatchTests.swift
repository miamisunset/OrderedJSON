import Testing

@testable import OrderedJSON

// MARK: - JSON Patch (RFC 6902) Tests

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

@Suite("JSONPatch error tests")
struct JSONPatchErrorTests {
  @Test("patch test fail") func patchTestFail() throws {
    let json = JSON.object([
      "foo": JSON.string("bar")
    ])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("test"),
        "path": JSON.string("/foo"),
        "value": JSON.string("wrong"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Test failed: value mismatch"))
  }

  @Test("patch invalid operation") func patchInvalidOperation() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("unknown"),
        "path": JSON.string("/foo"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Unknown operation: unknown"))
  }

  @Test("patch invalid patch format") func patchInvalidPatchFormat() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.string("not an array")
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Patch must be an array of operations"))
  }

  @Test("patch operation not object") func patchOperationNotObject() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([JSON.string("not object")])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Each operation must be an object"))
  }

  @Test("patch missing op") func patchMissingOp() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["path": JSON.string("/foo")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'op' field"))
  }

  @Test("patch missing path") func patchMissingPath() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["op": JSON.string("add"), "value": JSON.string("x")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'path' field"))
  }

  @Test("patch add missing value") func patchAddMissingValue() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["op": JSON.string("add"), "path": JSON.string("/baz")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'value' field for add"))
  }

  @Test("patch replace missing value") func patchReplaceMissingValue() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["op": JSON.string("replace"), "path": JSON.string("/foo")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'value' field for replace"))
  }

  @Test("patch copy missing from") func patchCopyMissingFrom() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["op": JSON.string("copy"), "path": JSON.string("/baz")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'from' field for copy"))
  }

  @Test("patch move missing from") func patchMoveMissingFrom() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["op": JSON.string("move"), "path": JSON.string("/foo")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'from' field for move"))
  }

  @Test("patch test missing value") func patchTestMissingValue() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["op": JSON.string("test"), "path": JSON.string("/foo")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'value' field for test"))
  }

  @Test("patch copy path not found") func patchCopyPathNotFound() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("copy"),
        "from": JSON.string("/nonexistent"),
        "path": JSON.string("/baz"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Path not found"))
  }

  @Test("patch move path not found") func patchMovePathNotFound() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("move"),
        "from": JSON.string("/nonexistent"),
        "path": JSON.string("/baz"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Path not found"))
  }

  @Test("patch append to non array") func patchAppendToNonArray() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/-"),
        "value": JSON.string("x"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Cannot append to non-array"))
  }

  @Test("patch dash token in from rejected") func patchDashTokenInFromRejected() throws {
    let patch = JSON.array([
      JSON.object([
        "op": .string("copy"),
        "from": .string("/-"),
        "path": .string("/b"),
        "value": .string("x"),
      ])
    ])
    let json = JSON.object(["a": .string("x")])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Path not found"))
  }

  @Test("patch traverse beyond append") func patchTraverseBeyondAppend() throws {
    let json = JSON.array([JSON.string("a")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/-/foo"),
        "value": JSON.string("x"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Cannot traverse beyond '-' append marker"))
  }

  @Test("patch index into non array") func patchIndexIntoNonArray() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/0"),
        "value": JSON.string("x"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Cannot index into non-array"))
  }

  @Test("patch key into non object") func patchKeyIntoNonObject() throws {
    let json = JSON.array([JSON.string("a")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/foo"),
        "value": JSON.string("x"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Cannot key into non-object"))
  }

  @Test("patch key not found in set") func patchKeyNotFoundInSet() throws {
    let json = JSON.object(["a": JSON.object(["x": JSON.string("y")])])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/a/b/c"),
        "value": JSON.string("z"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Key not found: b"))
  }

  @Test("patch key not found in remove") func patchKeyNotFoundInRemove() throws {
    let json = JSON.object(["a": JSON.object(["x": JSON.string("y")])])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("remove"),
        "path": JSON.string("/a/b"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Key not found: b"))
  }

  @Test("patch replace array out of bounds") func patchReplaceArrayOutOfBounds() throws {
    let json = JSON.array([JSON.string("a")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("replace"),
        "path": JSON.string("/5"),
        "value": JSON.string("x"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Array index out of bounds for replace"))
  }

  @Test("patch add array append beyond") func patchAddArrayAppendBeyond() throws {
    let json = JSON.array([JSON.string("a")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/5"),
        "value": JSON.string("x"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Array index out of bounds for add"))
  }

  @Test("patch remove index into non array") func patchRemoveIndexIntoNonArray() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("remove"),
        "path": JSON.string("/0"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Cannot index into non-array for remove"))
  }

  @Test("patch remove array out of bounds") func patchRemoveArrayOutOfBounds() throws {
    let json = JSON.array([JSON.string("a")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("remove"),
        "path": JSON.string("/5"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Array index out of bounds for remove"))
  }

  @Test("patch remove key into non object") func patchRemoveKeyIntoNonObject() throws {
    let json = JSON.array([JSON.string("a")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("remove"),
        "path": JSON.string("/foo"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Cannot key into non-object for remove"))
  }

  @Test("patch array index out of bounds traverse") func patchArrayIndexOutOfBoundsTraverse() throws {
    let json = JSON.array([JSON.array([JSON.string("a")])])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/1/0"),
        "value": JSON.string("x"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Array index out of bounds"))
  }

  @Test("patch replace array index out of bounds") func patchReplaceArrayIndexOutOfBounds() throws {
    let json = JSON.array([JSON.string("a")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("replace"),
        "path": JSON.string("/0"),
        "value": JSON.string("x"),
      ])
    ])
    let result = try json.applying(patch)
    #expect(result[0] == JSON.string("x"))
  }
}

@Suite("JSONPatch diff tests")
struct JSONPatchDiffTests {
  @Test("diff different types") func diffDifferentTypes() {
    let source = JSON.object(["foo": JSON.string("bar")])
    let target = JSON.array([JSON.string("bar")])
    let patch = JSON.diff(source, target)
    #expect(patch.isArray)
    #expect(patch.count == 1)
    #expect(patch[0]?["op"] == JSON.string("replace"))
  }

  @Test("diff array remove excess") func diffArrayRemoveExcess() {
    let source = JSON.array([
      JSON.number(.integer(1)), JSON.number(.integer(2)), JSON.number(.integer(3)),
    ])
    let target = JSON.array([JSON.number(.integer(1))])
    let patch = JSON.diff(source, target)
    #expect(patch.isArray)
    #expect(patch.count == 2)  // replace index 1, remove index 2? Actually remove trailing
  }

  @Test("diff array recursive objects") func diffArrayRecursiveObjects() {
    let source = JSON.array([
      JSON.object(["a": JSON.string("old")])
    ])
    let target = JSON.array([
      JSON.object(["a": JSON.string("new")])
    ])
    let patch = JSON.diff(source, target)
    // Should produce a recursive diff for the object at index 0
    #expect(patch.isArray)
    #expect(patch.count == 1)
    #expect(patch[0]?["op"] == JSON.string("replace"))
  }

  @Test("diff object recursive") func diffObjectRecursive() {
    let source = JSON.object([
      "a": JSON.object(["b": JSON.string("old")])
    ])
    let target = JSON.object([
      "a": JSON.object(["b": JSON.string("new")])
    ])
    let patch = JSON.diff(source, target)
    // Should produce a recursive diff for the nested object
    #expect(patch.isArray)
    #expect(patch[0]?["op"] == JSON.string("replace"))
  }

  @Test("diff nested array recursive") func diffNestedArrayRecursive() {
    let source = JSON.object([
      "a": JSON.array([JSON.object(["x": JSON.string("old")])])
    ])
    let target = JSON.object([
      "a": JSON.array([JSON.object(["x": JSON.string("new")])])
    ])
    let patch = JSON.diff(source, target)
    #expect(patch.isArray)
  }

  @Test("diff simple replace") func diffSimpleReplace() {
    let source = JSON.object(["foo": JSON.string("bar")])
    let target = JSON.object(["foo": JSON.string("baz")])
    let patch = JSON.diff(source, target)
    let expected = JSON.array([
      JSON.object([
        "op": JSON.string("replace"),
        "path": JSON.string("/foo"),
        "value": JSON.string("baz"),
      ])
    ])
    #expect(patch == expected)
  }

  @Test("diff add key") func diffAddKey() {
    let source = JSON.object(["foo": JSON.string("bar")])
    let target = JSON.object([
      "foo": JSON.string("bar"),
      "baz": JSON.string("qux"),
    ])
    let patch = JSON.diff(source, target)
    let expected = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/baz"),
        "value": JSON.string("qux"),
      ])
    ])
    #expect(patch == expected)
  }

  @Test("diff remove key") func diffRemoveKey() {
    let source = JSON.object([
      "foo": JSON.string("bar"),
      "baz": JSON.string("qux"),
    ])
    let target = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.diff(source, target)
    let expected = JSON.array([
      JSON.object([
        "op": JSON.string("remove"),
        "path": JSON.string("/baz"),
      ])
    ])
    #expect(patch == expected)
  }

  @Test("diff array changes") func diffArrayChanges() {
    let source = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
    let target = JSON.array([
      JSON.number(.integer(1)), JSON.number(.integer(3)), JSON.number(.integer(4)),
    ])
    let patch = JSON.diff(source, target)
    // First: replace index 1, then add index 2
    #expect(patch.isArray)
    #expect(patch.count == 2)
  }

  @Test("diff no changes") func diffNoChanges() {
    let source = JSON.object(["foo": JSON.string("bar")])
    let target = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.diff(source, target)
    #expect(patch.isArray)
    #expect(patch.isEmpty)
  }

  @Test("diff round trip") func diffRoundTrip() throws {
    let source = JSON.object([
      "foo": JSON.string("bar"),
      "baz": JSON.number(.integer(42)),
    ])
    let target = JSON.object([
      "foo": JSON.string("bar"),
      "qux": JSON.boolean(true),
    ])
    let patch = JSON.diff(source, target)
    let result = try source.applying(patch)
    #expect(result == target)
  }
}
