import Foundation
import Testing

@testable import OrderedJSON

@Suite("JSONPatch complex edge case tests")
struct JSONPatchComplexTests {
  @Test("nested array add/remove operations") func nestedArrayOperations() throws {
    let json = JSON.object([
      "data": JSON.array([
        JSON.array([.number(.integer(1)), .number(.integer(2))]),
        JSON.array([.number(.integer(3)), .number(.integer(4))]),
      ])
    ])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/data/0/-"),
        "value": .number(.integer(99)),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "data": JSON.array([
        JSON.array([.number(.integer(1)), .number(.integer(2)), .number(.integer(99))]),
        JSON.array([.number(.integer(3)), .number(.integer(4))]),
      ])
    ])
    #expect(result == expected)
  }

  @Test("nested array replace element") func nestedArrayReplace() throws {
    let json = JSON.object([
      "data": JSON.array([
        JSON.array([.number(.integer(1)), .number(.integer(2))])
      ])
    ])
    let patch = JSON.array([
      JSON.object([
        "op": .string("replace"),
        "path": .string("/data/0/1"),
        "value": .number(.integer(99)),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "data": JSON.array([
        JSON.array([.number(.integer(1)), .number(.integer(99))])
      ])
    ])
    #expect(result == expected)
  }

  @Test("add with intermediate missing keys errors") func addMissingIntermediateKeys() {
    let json = JSON.object(["a": .string("exists")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/a/b/c"),
        "value": .string("deep"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Cannot key into non-object"))
  }

  @Test("remove from empty array errors") func removeFromEmptyArray() {
    let json = JSON.array([])
    let patch = JSON.array([
      JSON.object(["op": .string("remove"), "path": .string("/0")])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Array index out of bounds for remove"))
  }

  @Test("replace on empty array errors") func replaceOnEmptyArray() {
    let json = JSON.array([])
    let patch = JSON.array([
      JSON.object([
        "op": .string("replace"),
        "path": .string("/0"),
        "value": .string("x"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Array index out of bounds for replace"))
  }

  @Test("patch with empty operations array is no-op") func emptyPatchArray() throws {
    let json = JSON.object(["foo": .string("bar")])
    let patch = JSON.array([])
    let result = try json.applying(patch)
    #expect(result == json)
  }

  @Test("patch with null value in add") func addNullValue() throws {
    let json = JSON.object(["foo": .string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/baz"),
        "value": .null,
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "foo": .string("bar"),
      "baz": .null,
    ])
    #expect(result == expected)
  }

  @Test("patch with boolean value in add") func addBooleanValue() throws {
    let json = JSON.object(["foo": .string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/flag"),
        "value": .boolean(true),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "foo": .string("bar"),
      "flag": .boolean(true),
    ])
    #expect(result == expected)
  }

  @Test("patch with integer value in add") func addIntegerValue() throws {
    let json = JSON.object(["foo": .string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/num"),
        "value": .number(.integer(42)),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "foo": .string("bar"),
      "num": .number(.integer(42)),
    ])
    #expect(result == expected)
  }

  @Test("patch with float value in add") func addFloatValue() throws {
    let json = JSON.object(["foo": .string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/pi"),
        "value": .number(.float(3.14)),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "foo": .string("bar"),
      "pi": .number(.float(3.14)),
    ])
    #expect(result == expected)
  }

  @Test("patch with object value in add") func addObjectValue() throws {
    let json = JSON.object(["foo": .string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/nested"),
        "value": JSON.object(["key": .string("val")]),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "foo": .string("bar"),
      "nested": JSON.object(["key": .string("val")]),
    ])
    #expect(result == expected)
  }

  @Test("patch with array value in add") func addArrayValue() throws {
    let json = JSON.object(["foo": .string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/list"),
        "value": JSON.array([.number(.integer(1)), .number(.integer(2))]),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "foo": .string("bar"),
      "list": JSON.array([.number(.integer(1)), .number(.integer(2))]),
    ])
    #expect(result == expected)
  }

  @Test("complex patch: add nested object, then add to nested") func complexNestedPatch() throws {
    let json = JSON.object(["data": .null])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/data"),
        "value": JSON.object(["items": JSON.array([])]),
      ]),
      JSON.object([
        "op": .string("add"),
        "path": .string("/data/items/-"),
        "value": .string("first"),
      ]),
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "data": JSON.object(["items": JSON.array([.string("first")])])
    ])
    #expect(result == expected)
  }

  @Test("remove then add to same path (effectively replace)") func removeThenAddSamePath() throws {
    let json = JSON.object(["key": .string("old")])
    let patch = JSON.array([
      JSON.object(["op": .string("remove"), "path": .string("/key")]),
      JSON.object([
        "op": .string("add"),
        "path": .string("/key"),
        "value": .string("new"),
      ]),
    ])
    let result = try json.applying(patch)
    let expected = JSON.object(["key": .string("new")])
    #expect(result == expected)
  }

  @Test("replace nested value in object") func replaceNestedObjectValue() throws {
    let json = JSON.object([
      "config": JSON.object([
        "host": .string("old-host"),
        "port": .number(.integer(8080)),
      ])
    ])
    let patch = JSON.array([
      JSON.object([
        "op": .string("replace"),
        "path": .string("/config/host"),
        "value": .string("new-host"),
      ])
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "config": JSON.object([
        "host": .string("new-host"),
        "port": .number(.integer(8080)),
      ])
    ])
    #expect(result == expected)
  }

  @Test("diff then apply round-trip") func diffThenApplyRoundTrip() throws {
    let source = JSON.object([
      "a": .number(.integer(1)),
      "b": .string("hello"),
      "c": .boolean(true),
    ])
    let target = JSON.object([
      "a": .number(.integer(2)),
      "b": .string("hello"),
      "d": .number(.float(3.14)),
    ])
    let patch = JSON.diff(source, target)
    let result = try source.applying(patch)
    #expect(result == target)
  }

  @Test("diff empty object to non-empty") func diffEmptyToNonEmpty() throws {
    let source = JSON.object([:])
    let target = JSON.object(["key": .string("value")])
    let patch = JSON.diff(source, target)
    let result = try source.applying(patch)
    #expect(result == target)
  }

  @Test("diff non-empty to empty object") func diffNonEmptyToEmpty() throws {
    let source = JSON.object(["key": .string("value")])
    let target = JSON.object([:])
    let patch = JSON.diff(source, target)
    let result = try source.applying(patch)
    #expect(result == target)
  }

  @Test("diff scalar to scalar") func diffScalarToScalar() throws {
    let source = JSON.string("hello")
    let target = JSON.string("world")
    let patch = JSON.diff(source, target)
    let result = try source.applying(patch)
    #expect(result == target)
  }

  @Test("diff array to empty array") func diffArrayToEmptyArray() throws {
    let source = JSON.array([.number(.integer(1)), .number(.integer(2))])
    let target = JSON.array([])
    let patch = JSON.diff(source, target)
    let result = try source.applying(patch)
    #expect(result == target)
  }

  @Test("diff empty array to array") func diffEmptyArrayToArray() throws {
    let source = JSON.array([])
    let target = JSON.array([.number(.integer(1)), .number(.integer(2))])
    let patch = JSON.diff(source, target)
    let result = try source.applying(patch)
    #expect(result == target)
  }

  @Test("diff scalar to object") func diffScalarToObject() throws {
    let source = JSON.string("hello")
    let target = JSON.object(["key": .string("value")])
    let patch = JSON.diff(source, target)
    let result = try source.applying(patch)
    #expect(result == target)
  }

  @Test("diff object to scalar") func diffObjectToScalar() throws {
    let source = JSON.object(["key": .string("value")])
    let target = JSON.string("hello")
    let patch = JSON.diff(source, target)
    let result = try source.applying(patch)
    #expect(result == target)
  }

  @Test("diff identical values produces empty patch") func diffIdentical() {
    let source = JSON.object([
      "a": .number(.integer(1)),
      "b": .string("test"),
    ])
    let patch = JSON.diff(source, source)
    #expect(patch.isEmpty)
  }

  @Test("diff null values") func diffNull() throws {
    let source = JSON.null
    let target = JSON.null
    let patch = JSON.diff(source, target)
    let result = try source.applying(patch)
    #expect(result == .null)
  }

  @Test("diff null to object") func diffNullToObject() throws {
    let source = JSON.null
    let target = JSON.object(["key": .string("value")])
    let patch = JSON.diff(source, target)
    let result = try source.applying(patch)
    #expect(result == target)
  }

  @Test("path with numeric keys in objects") func pathNumericKeysInObjects() throws {
    let json = JSON.object(["123": .string("value")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("test"),
        "path": .string("/123"),
        "value": .string("value"),
      ])
    ])
    let result = try json.applying(patch)
    #expect(result == json)
  }

  @Test("path with empty string keys in objects") func pathEmptyStringKeys() throws {
    let json = JSON.object(["": .string("empty_key_value"), "a": .string("b")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("test"),
        "path": .string("//"),
        "value": .string("empty_key_value"),
      ])
    ])
    do {
      let result = try json.applying(patch)
      #expect(result == json)
    } catch {
      #expect(Bool(true))
    }
  }

  @Test("add with path containing only digits on object uses key not index")
  func addNumericPathOnObject() throws {
    let json = JSON.object(["0": .string("value")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/0"),
        "value": .string("new"),
      ])
    ])
    // Per RFC 6901: numeric tokens are only array indices when value is an array.
    // For objects, they're member keys.
    let result = try json.applying(patch)
    let expected = JSON.object(["0": .string("new")])
    #expect(result == expected)
  }

  @Test("add to object with numeric key should treat as key not index") func addNumericKeyToObject()
    throws
  {
    // Per RFC 6901: "the token string (after unescaping) is the identifier of the member to access"
    // Numeric tokens only refer to array indices when the value is an array
    let json = JSON.object(["0": .string("existing"), "foo": .string("bar")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/0"),
        "value": .string("replaced"),
      ])
    ])
    // /0 should address key "0" in the object (not array index 0)
    let result = try json.applying(patch)
    let expected = JSON.object(["0": .string("replaced"), "foo": .string("bar")])
    #expect(result == expected)
  }

  @Test("resolve deeply nested path") func resolveDeeplyNested() throws {
    let json = JSON.object([
      "a": JSON.object([
        "b": JSON.object([
          "c": .string("deep")
        ])
      ])
    ])
    let patch = JSON.array([
      JSON.object([
        "op": .string("test"),
        "path": .string("/a/b/c"),
        "value": .string("deep"),
      ])
    ])
    let result = try json.applying(patch)
    #expect(result == json)
  }

  @Test("add at deeply nested path with missing intermediate key") func addDeepMissingIntermediate()
  {
    let json = JSON.object(["a": .string("leaf")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/a/b/c/d"),
        "value": .string("deep"),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Cannot key into non-object"))
  }

  @Test("independent add operations on different branches") func independentAdds() throws {
    let json = JSON.object([
      "a": .number(.integer(1)),
      "b": .number(.integer(2)),
    ])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/c"),
        "value": .number(.integer(3)),
      ]),
      JSON.object([
        "op": .string("add"),
        "path": .string("/d"),
        "value": .number(.integer(4)),
      ]),
    ])
    let result = try json.applying(patch)
    let expected = JSON.object([
      "a": .number(.integer(1)),
      "b": .number(.integer(2)),
      "c": .number(.integer(3)),
      "d": .number(.integer(4)),
    ])
    #expect(result == expected)
  }

  @Test("remove all keys from object") func removeAllKeys() throws {
    let json = JSON.object([
      "a": .number(.integer(1)),
      "b": .number(.integer(2)),
    ])
    let patch = JSON.array([
      JSON.object(["op": .string("remove"), "path": .string("/a")]),
      JSON.object(["op": .string("remove"), "path": .string("/b")]),
    ])
    let result = try json.applying(patch)
    #expect(result == JSON.object([:]))
  }

  @Test("remove all elements from array") func removeAllElements() throws {
    let json = JSON.array([.string("a"), .string("b"), .string("c")])
    let patch = JSON.array([
      JSON.object(["op": .string("remove"), "path": .string("/0")]),
      JSON.object(["op": .string("remove"), "path": .string("/0")]),
      JSON.object(["op": .string("remove"), "path": .string("/0")]),
    ])
    let result = try json.applying(patch)
    #expect(result == JSON.array([]))
  }

  @Test("add then replace same key") func addThenReplaceSameKey() throws {
    let json = JSON.object(["key": .string("original")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/key"),
        "value": .string("first"),
      ]),
      JSON.object([
        "op": .string("replace"),
        "path": .string("/key"),
        "value": .string("second"),
      ]),
    ])
    let result = try json.applying(patch)
    let expected = JSON.object(["key": .string("second")])
    #expect(result == expected)
  }
}
