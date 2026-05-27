import Testing

@testable import OrderedJSON

// MARK: - JSON Patch (RFC 6902) Tests

@Test func patchAddToObject() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("add"),
      "path": JSON.string("/baz"),
      "value": JSON.string("qux"),
    ])
  ])
  let result = try json.patch(patch)
  let expected = JSON.object([
    "foo": JSON.string("bar"),
    "baz": JSON.string("qux"),
  ])
  #expect(result == expected)
}

@Test func patchAddToArray() throws {
  let json = JSON.array([JSON.string("a"), JSON.string("b")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("add"),
      "path": JSON.string("/1"),
      "value": JSON.string("c"),
    ])
  ])
  let result = try json.patch(patch)
  let expected = JSON.array([JSON.string("a"), JSON.string("c"), JSON.string("b")])
  #expect(result == expected)
}

@Test func patchAddAppendToArray() throws {
  let json = JSON.array([JSON.string("a"), JSON.string("b")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("add"),
      "path": JSON.string("/-"),
      "value": JSON.string("c"),
    ])
  ])
  let result = try json.patch(patch)
  let expected = JSON.array([JSON.string("a"), JSON.string("b"), JSON.string("c")])
  #expect(result == expected)
}

@Test func patchRemoveFromObject() throws {
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
  let result = try json.patch(patch)
  let expected = JSON.object(["foo": JSON.string("bar")])
  #expect(result == expected)
}

@Test func patchRemoveFromArray() throws {
  let json = JSON.array([JSON.string("a"), JSON.string("b"), JSON.string("c")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("remove"),
      "path": JSON.string("/1"),
    ])
  ])
  let result = try json.patch(patch)
  let expected = JSON.array([JSON.string("a"), JSON.string("c")])
  #expect(result == expected)
}

@Test func patchReplaceValue() throws {
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
  let result = try json.patch(patch)
  let expected = JSON.object(["foo": JSON.number(.integer(42))])
  #expect(result == expected)
}

@Test func patchCopyValue() throws {
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
  let result = try json.patch(patch)
  let expected = JSON.object([
    "foo": JSON.string("bar"),
    "baz": JSON.string("bar"),
  ])
  #expect(result == expected)
}

@Test func patchMoveValue() throws {
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
  let result = try json.patch(patch)
  let expected = JSON.object([
    "foo": JSON.string("qux")
  ])
  #expect(result == expected)
}

@Test func patchTestPass() throws {
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
  let result = try json.patch(patch)
  #expect(result == json)
}

@Test func patchTestFail() throws {
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
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchInvalidOperation() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("unknown"),
      "path": JSON.string("/foo"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchInvalidPatchFormat() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.string("not an array")
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchInPlaceMutates() throws {
  var json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("add"),
      "path": JSON.string("/baz"),
      "value": JSON.string("qux"),
    ])
  ])
  try json.patchInPlace(patch)
  let expected = JSON.object([
    "foo": JSON.string("bar"),
    "baz": JSON.string("qux"),
  ])
  #expect(json == expected)
}

// MARK: - Patch Error Cases

@Test func patchOperationNotObject() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([JSON.string("not object")])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchMissingOp() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object(["path": JSON.string("/foo")])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchMissingPath() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object(["op": JSON.string("add"), "value": JSON.string("x")])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchAddMissingValue() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object(["op": JSON.string("add"), "path": JSON.string("/baz")])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchReplaceMissingValue() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object(["op": JSON.string("replace"), "path": JSON.string("/foo")])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchCopyMissingFrom() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object(["op": JSON.string("copy"), "path": JSON.string("/baz")])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchMoveMissingFrom() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object(["op": JSON.string("move"), "path": JSON.string("/foo")])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchTestMissingValue() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object(["op": JSON.string("test"), "path": JSON.string("/foo")])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchCopyPathNotFound() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("copy"),
      "from": JSON.string("/nonexistent"),
      "path": JSON.string("/baz"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchMovePathNotFound() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("move"),
      "from": JSON.string("/nonexistent"),
      "path": JSON.string("/baz"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchAppendToNonArray() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("add"),
      "path": JSON.string("/-"),
      "value": JSON.string("x"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchDashTokenInFromRejected() throws {
  // Regression: '-' token in 'from' path should be rejected (not treated as object key)
  let patch = JSON.array([
    JSON.object([
      "op": .string("copy"),
      "from": .string("/-"),
      "path": .string("/b"),
      "value": .string("x"),
    ])
  ])
  let json = JSON.object(["a": .string("x")])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchTraverseBeyondAppend() throws {
  let json = JSON.array([JSON.string("a")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("add"),
      "path": JSON.string("/-/foo"),
      "value": JSON.string("x"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchIndexIntoNonArray() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("add"),
      "path": JSON.string("/0"),
      "value": JSON.string("x"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchKeyIntoNonObject() throws {
  let json = JSON.array([JSON.string("a")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("add"),
      "path": JSON.string("/foo"),
      "value": JSON.string("x"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchKeyNotFoundInSet() throws {
  let json = JSON.object(["a": JSON.object(["x": JSON.string("y")])])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("add"),
      "path": JSON.string("/a/b/c"),
      "value": JSON.string("z"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchKeyNotFoundInRemove() throws {
  let json = JSON.object(["a": JSON.object(["x": JSON.string("y")])])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("remove"),
      "path": JSON.string("/a/b"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchReplaceArrayOutOfBounds() throws {
  let json = JSON.array([JSON.string("a")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("replace"),
      "path": JSON.string("/5"),
      "value": JSON.string("x"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchAddArrayAppendBeyond() throws {
  // RFC 6902: adding at an index greater than the array length MUST fail
  let json = JSON.array([JSON.string("a")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("add"),
      "path": JSON.string("/5"),
      "value": JSON.string("x"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchRemoveIndexIntoNonArray() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("remove"),
      "path": JSON.string("/0"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchRemoveArrayOutOfBounds() throws {
  let json = JSON.array([JSON.string("a")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("remove"),
      "path": JSON.string("/5"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchRemoveKeyIntoNonObject() throws {
  let json = JSON.array([JSON.string("a")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("remove"),
      "path": JSON.string("/foo"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchArrayIndexOutOfBoundsTraverse() throws {
  let json = JSON.array([JSON.array([JSON.string("a")])])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("add"),
      "path": JSON.string("/1/0"),
      "value": JSON.string("x"),
    ])
  ])
  #expect(throws: JSONError.self) { try json.patch(patch) }
}

@Test func patchReplaceArrayIndexOutOfBounds() throws {
  let json = JSON.array([JSON.string("a")])
  let patch = JSON.array([
    JSON.object([
      "op": JSON.string("replace"),
      "path": JSON.string("/0"),
      "value": JSON.string("x"),
    ])
  ])
  let result = try json.patch(patch)
  #expect(result[0] == JSON.string("x"))
}

// MARK: - Diff Edge Cases

@Test func diffDifferentTypes() {
  let source = JSON.object(["foo": JSON.string("bar")])
  let target = JSON.array([JSON.string("bar")])
  let patch = JSON.diff(source, target)
  #expect(patch.isArray)
  #expect(patch.count == 1)
  #expect(patch[0]?["op"] == JSON.string("replace"))
}

@Test func diffArrayRemoveExcess() {
  let source = JSON.array([
    JSON.number(.integer(1)), JSON.number(.integer(2)), JSON.number(.integer(3)),
  ])
  let target = JSON.array([JSON.number(.integer(1))])
  let patch = JSON.diff(source, target)
  #expect(patch.isArray)
  #expect(patch.count == 2)  // replace index 1, remove index 2? Actually remove trailing
}

@Test func diffArrayRecursiveObjects() {
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

@Test func diffObjectRecursive() {
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

@Test func diffNestedArrayRecursive() {
  let source = JSON.object([
    "a": JSON.array([JSON.object(["x": JSON.string("old")])])
  ])
  let target = JSON.object([
    "a": JSON.array([JSON.object(["x": JSON.string("new")])])
  ])
  let patch = JSON.diff(source, target)
  #expect(patch.isArray)
}

@Test func diffSimpleReplace() {
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

@Test func diffAddKey() {
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

@Test func diffRemoveKey() {
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

@Test func diffArrayChanges() {
  let source = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
  let target = JSON.array([
    JSON.number(.integer(1)), JSON.number(.integer(3)), JSON.number(.integer(4)),
  ])
  let patch = JSON.diff(source, target)
  // First: replace index 1, then add index 2
  #expect(patch.isArray)
  #expect(patch.count == 2)
}

@Test func diffNoChanges() {
  let source = JSON.object(["foo": JSON.string("bar")])
  let target = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.diff(source, target)
  #expect(patch.isArray)
  #expect(patch.isEmpty)
}

@Test func diffRoundTrip() throws {
  let source = JSON.object([
    "foo": JSON.string("bar"),
    "baz": JSON.number(.integer(42)),
  ])
  let target = JSON.object([
    "foo": JSON.string("bar"),
    "qux": JSON.boolean(true),
  ])
  let patch = JSON.diff(source, target)
  let result = try source.patch(patch)
  #expect(result == target)
}
