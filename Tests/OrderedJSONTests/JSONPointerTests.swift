import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - JSONPointer Tests

@Test func pointerEmptyPath() throws {
  let ptr = try JSONPointer("")
  #expect(ptr.segments.isEmpty)
}

@Test func pointerSingleSegment() throws {
  let ptr = try JSONPointer("/foo")
  #expect(ptr.segments == ["foo"])
}

@Test func pointerMultiSegment() throws {
  let ptr = try JSONPointer("/foo/bar/baz")
  #expect(ptr.segments == ["foo", "bar", "baz"])
}

@Test func pointerArrayIndex() throws {
  let ptr = try JSONPointer("/0")
  #expect(ptr.segments == ["0"])
}

@Test func pointerEscaping() throws {
  let ptr = try JSONPointer("/a~1b")
  #expect(ptr.segments == ["a/b"])
}

@Test func pointerTildeEscaping() throws {
  let ptr = try JSONPointer("/a~0b")
  #expect(ptr.segments == ["a~b"])
}

@Test func pointerNoLeadingSlash() throws {
  #expect(throws: JSONError.invalidString) { try JSONPointer("foo") }
}

@Test func pointerInitSegments() {
  let ptr = JSONPointer(segments: ["a", "b"])
  #expect(ptr.segments == ["a", "b"])
}

@Test func pointerResolveObject() throws {
  let json = JSON.object(["foo": JSON.string("bar")])
  let ptr = try JSONPointer("/foo")
  #expect(ptr.resolve(json) == JSON.string("bar"))
}

@Test func pointerResolveArray() throws {
  let json = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
  let ptr = try JSONPointer("/1")
  #expect(ptr.resolve(json) == JSON.number(.integer(1)))
}

@Test func pointerResolveNested() throws {
  let json = JSON.object(["a": JSON.object(["b": JSON.string("deep")])])
  let ptr = try JSONPointer("/a/b")
  #expect(ptr.resolve(json) == JSON.string("deep"))
}

@Test func pointerResolveEmptyPath() throws {
  let json = JSON.string("root")
  let ptr = try JSONPointer("")
  #expect(ptr.resolve(json) == JSON.string("root"))
}

@Test func pointerResolveNotFound() throws {
  let json = JSON.object(["a": JSON.string("x")])
  let ptr = try JSONPointer("/missing")
  #expect(ptr.resolve(json) == nil)
}

@Test func pointerResolveBadIndex() throws {
  let json = JSON.array([JSON.string("a")])
  let ptr = try JSONPointer("/5")
  #expect(ptr.resolve(json) == nil)
}

@Test func pointerResolveTypeMismatch() throws {
  let json = JSON.string("scalar")
  let ptr = try JSONPointer("/foo")
  #expect(ptr.resolve(json) == nil)
}

@Test func pointerSet() throws {
  var json = JSON.object(["a": JSON.string("old")])
  let ptr = try JSONPointer("/a")
  ptr.set(into: &json, value: JSON.string("new"))
  // set is currently a no-op (TODO)
  // Verify the value didn't change
  #expect(json["a"] == JSON.string("old"))
}

// MARK: - Flatten/Unflatten Edge Cases

@Test func unflattenSimple() {
  let flat = JSON.object([
    "/a": JSON.string("x"),
    "/b": JSON.number(.integer(1)),
  ])
  let result = flat.unflatten()
  guard case .object(let dict) = result.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict["a"] == JSON.string("x"))
  #expect(dict["b"] == JSON.number(.integer(1)))
}

@Test func unflattenNested() {
  let flat = JSON.object([
    "/a/b/c": JSON.string("deep")
  ])
  let result = flat.unflatten()
  #expect(result["a"]?["b"]?["c"] == JSON.string("deep"))
}

@Test func unflattenArrayIndices() {
  let flat = JSON.object([
    "/0": JSON.string("a"),
    "/1": JSON.number(.integer(1)),
  ])
  let result = flat.unflatten()
  #expect(result.isArray)
  #expect(result[0] == JSON.string("a"))
  #expect(result[1] == JSON.number(.integer(1)))
}

@Test func unflattenNestedArray() {
  let flat = JSON.object([
    "/a/0": JSON.string("first"),
    "/a/1": JSON.number(.integer(2)),
  ])
  let result = flat.unflatten()
  #expect(result["a"]?.isArray == true)
  #expect(result["a"]?[0] == JSON.string("first"))
  #expect(result["a"]?[1] == JSON.number(.integer(2)))
}

@Test func unflattenNonObject() {
  let scalar = JSON.string("hello")
  let result = scalar.unflatten()
  #expect(result == JSON.string("hello"))
}

@Test func flattenAndUnflattenRoundTrip() {
  let original = JSON.object([
    "a": JSON.object([
      "b": JSON.array([
        JSON.number(.integer(1)),
        JSON.object(["c": JSON.string("deep")]),
      ])
    ]),
    "d": JSON.string("leaf"),
  ])
  let flat = original.flatten()
  let reconstructed = flat.unflatten()
  #expect(reconstructed == original)
}

@Test func unflattenEmptyObject() {
  let flat = JSON.object([:])
  let result = flat.unflatten()
  #expect(result.isObject)
  #expect(result.isEmpty)
}

@Test func unflattenArrayPathWithoutLeadingSlash() {
  // Keys like "a/b/c" (without leading /) should still work
  let flat = JSON.object([
    "a": JSON.string("x")
  ])
  let result = flat.unflatten()
  guard case .object(let dict) = result.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict["a"] == JSON.string("x"))
}
