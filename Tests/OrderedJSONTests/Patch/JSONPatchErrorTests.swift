import Testing

@testable import OrderedJSON

@Suite("JSONPatch error tests")
struct JSONPatchErrorTests {
  @Test("patch test fail") func patchTestFail() {
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

  @Test("patch invalid operation") func patchInvalidOperation() {
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

  @Test("patch invalid patch format") func patchInvalidPatchFormat() {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.string("not an array")
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Patch must be an array of operations"))
  }

  @Test("patch operation not object") func patchOperationNotObject() {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([JSON.string("not object")])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Each operation must be an object"))
  }

  @Test("patch missing op") func patchMissingOp() {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["path": JSON.string("/foo")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'op' field"))
  }

  @Test("patch missing path") func patchMissingPath() {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["op": JSON.string("add"), "value": JSON.string("x")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'path' field"))
  }

  @Test("patch add missing value") func patchAddMissingValue() {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["op": JSON.string("add"), "path": JSON.string("/baz")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'value' field for add"))
  }

  @Test("patch replace missing value") func patchReplaceMissingValue() {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["op": JSON.string("replace"), "path": JSON.string("/foo")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'value' field for replace"))
  }

  @Test("patch copy missing from") func patchCopyMissingFrom() {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["op": JSON.string("copy"), "path": JSON.string("/baz")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'from' field for copy"))
  }

  @Test("patch move missing from") func patchMoveMissingFrom() {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["op": JSON.string("move"), "path": JSON.string("/foo")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'from' field for move"))
  }

  @Test("patch test missing value") func patchTestMissingValue() {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object(["op": JSON.string("test"), "path": JSON.string("/foo")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Missing 'value' field for test"))
  }

  @Test("patch copy path not found") func patchCopyPathNotFound() {
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

  @Test("patch move path not found") func patchMovePathNotFound() {
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

  @Test("patch append to non array") func patchAppendToNonArray() {
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

  @Test("patch dash token in from rejected") func patchDashTokenInFromRejected() {
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

  @Test("patch traverse beyond append") func patchTraverseBeyondAppend() {
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

  @Test("patch index into non array treats as key") func patchIndexIntoNonArray() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/0"),
        "value": JSON.string("x"),
      ])
    ])
    // Per RFC 6901: numeric tokens on objects are member keys, not array indices
    let result = try json.applying(patch)
    let expected = JSON.object(["foo": JSON.string("bar"), "0": JSON.string("x")])
    #expect(result == expected)
  }

  @Test("patch key into non object") func patchKeyIntoNonObject() {
    let json = JSON.array([JSON.string("a")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/foo"),
        "value": JSON.string("x"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Cannot index into non-array"))
  }

  @Test("patch key not found in set") func patchKeyNotFoundInSet() {
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

  @Test("patch key not found in remove") func patchKeyNotFoundInRemove() {
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

  @Test("patch replace array out of bounds") func patchReplaceArrayOutOfBounds() {
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

  @Test("patch add array append beyond") func patchAddArrayAppendBeyond() {
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

  @Test("patch remove index into non array treats as key") func patchRemoveIndexIntoNonArray() {
    let json = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("remove"),
        "path": JSON.string("/0"),
      ])
    ])
    // Per RFC 6901: numeric tokens on objects are member keys. Key "0" doesn't exist.
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Key not found: 0"))
  }

  @Test("patch remove array out of bounds") func patchRemoveArrayOutOfBounds() {
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

  @Test("patch remove key into non object") func patchRemoveKeyIntoNonObject() {
    let json = JSON.array([JSON.string("a")])
    let patch = JSON.array([
      JSON.object([
        "op": JSON.string("remove"),
        "path": JSON.string("/foo"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Cannot index into non-array for remove"))
  }

  @Test("patch array index out of bounds traverse") func patchArrayIndexOutOfBoundsTraverse() {
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
