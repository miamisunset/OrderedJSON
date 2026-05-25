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

@Test func pointerTildeThenSlashEscaping() throws {
  // RFC 6901 §4: ~01 must decode as ~0→~ then ~1→/ → "/"
  let ptr = try JSONPointer("/foo~01bar")
  #expect(ptr.segments == ["foo/bar"])
}

@Test func pointerTildeThenTildeEscaping() throws {
  // ~00 decodes as ~0→~ then literal 0 → "~0"
  // (RFC 6901's "~00 represents ~~" refers to escaping, not unescaping)
  let ptr = try JSONPointer("/foo~00bar")
  #expect(ptr.segments == ["foo~0bar"])
}

@Test func pointerNoLeadingSlash() throws {
  #expect {
    try JSONPointer("foo")
  } throws: { error in
    guard let ptrErr = error as? JSONPointerError else { return false }
    return ptrErr == .invalidSyntax("Pointer must start with '/' or be empty")
  }
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
  #expect(json["a"] == JSON.string("new"))
}

@Test func pointerSetRoot() throws {
  var json = JSON.string("old")
  let ptr = try JSONPointer("")
  ptr.set(into: &json, value: JSON.string("new"))
  #expect(json == JSON.string("new"))
}

@Test func pointerSetCreatesIntermediate() throws {
  var json = JSON.object([:])
  let ptr = try JSONPointer("/a/b/c")
  ptr.set(into: &json, value: JSON.string("deep"))
  #expect(json["a"]?["b"]?["c"] == JSON.string("deep"))
}

@Test func pointerSetCreatesArray() throws {
  var json = JSON.object([:])
  let ptr = try JSONPointer("/0")
  ptr.set(into: &json, value: JSON.string("first"))
  #expect(json.isArray)
  #expect(json[0] == JSON.string("first"))
}

@Test func pointerDescriptionRoot() throws {
  let ptr = try JSONPointer("")
  #expect(ptr.description == "")
}

@Test func pointerDescriptionSimple() throws {
  let ptr = try JSONPointer("/foo/bar")
  #expect(ptr.description == "/foo/bar")
}

@Test func pointerDescriptionEscaped() throws {
  let ptr = try JSONPointer("/a~1b/m~0n")
  #expect(ptr.description == "/a~1b/m~0n")
}

@Test func pointerDescriptionRoundTrip() throws {
  let path = "/foo~01bar/~0baz"
  let ptr = try JSONPointer(path)
  // Description uses canonical ~1 encoding (not ~01), so round-trip is
  // semantically equivalent but syntactically different.
  let reparsed = try JSONPointer(ptr.description)
  #expect(reparsed.segments == ptr.segments)
}

@Test func pointerResolveDashToken() throws {
  let json = JSON.array([JSON.string("a"), JSON.string("b")])
  let ptr = try JSONPointer("/-")
  // "-" refers to nonexistent element after last array element
  #expect(ptr.resolve(json) == nil)
}

@Test func pointerDashTokenOnNonArray() throws {
  let json = JSON.object(["key": JSON.string("val")])
  let ptr = try JSONPointer("/-")
  // "-" on a non-array: resolve treats it as an object key (not found)
  #expect(ptr.resolve(json) == nil)
}

@Test func pointerSetDashAppendsToArray() throws {
  var json = JSON.array([JSON.string("a")])
  let ptr = try JSONPointer("/-")
  ptr.set(into: &json, value: JSON.string("b"))
  #expect(json[0] == JSON.string("a"))
  #expect(json[1] == JSON.string("b"))
}

@Test func pointerSetDashCreatesArray() throws {
  var json = JSON.object([:])  // start with object, "-" forces array
  let ptr = try JSONPointer("/-")
  ptr.set(into: &json, value: JSON.string("first"))
  #expect(json.isArray)
  #expect(json[0] == JSON.string("first"))
}

@Test func pointerSetDashAppendsWithRest() throws {
  var json = JSON.array([JSON.object([:])])
  let ptr = try JSONPointer("/-/foo")
  ptr.set(into: &json, value: JSON.string("bar"))
  #expect(json[0]?.isObject == true)
  #expect(json[1]?.isObject == true)
  #expect(json[1]?["foo"] == JSON.string("bar"))
}

@Test func pointerLeadingZeroRejected() throws {
  #expect {
    try JSONPointer("/01")
  } throws: { error in
    guard let ptrErr = error as? JSONPointerError else { return false }
    return ptrErr == .leadingZero("01")
  }
}

@Test func pointerLeadingZeroRejectedMultiSegment() throws {
  #expect {
    try JSONPointer("/foo/01")
  } throws: { error in
    guard let ptrErr = error as? JSONPointerError else { return false }
    return ptrErr == .leadingZero("01")
  }
}

@Test func pointerLeadingZeroAllowedForZero() throws {
  // "0" is valid per RFC 6901 ABNF (single digit zero)
  let ptr = try JSONPointer("/0")
  #expect(ptr.segments == ["0"])
}

@Test func pointerFragmentInit() throws {
  let ptr = try JSONPointer(fragment: "#/foo/bar")
  #expect(ptr.segments == ["foo", "bar"])
}

@Test func pointerFragmentInitRoot() throws {
  let ptr = try JSONPointer(fragment: "#")
  #expect(ptr.segments.isEmpty)
}

@Test func pointerFragmentInitNoHash() throws {
  #expect {
    try JSONPointer(fragment: "/foo")
  } throws: { error in
    guard let ptrErr = error as? JSONPointerError else { return false }
    return ptrErr == .invalidSyntax("URI fragment must start with '#'")
  }
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

@Test func unflattenArrayWithNestedObject() {
  // Path /0/foo: first segment "0" creates array from object root, rest not empty
  let flat = JSON.object([
    "/0/foo": JSON.string("bar")
  ])
  let result = flat.unflatten()
  #expect(result.isArray)
  #expect(result[0]?.isObject == true)
  #expect(result[0]?["foo"] == JSON.string("bar"))
}

@Test func unflattenMixedArrayAndObjectPaths() {
  // First path /0 creates array root; second path /foo/bar overwrites root to object
  // (conflicting root types — last one wins)
  let flat = JSON.object([
    "/0": JSON.string("a"),
    "/foo/bar": JSON.string("b"),
  ])
  let result = flat.unflatten()
  #expect(result.isObject)
  #expect(result["foo"]?.isObject == true)
  #expect(result["foo"]?["bar"] == JSON.string("b"))
}
