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

// MARK: - Diff Tests

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
