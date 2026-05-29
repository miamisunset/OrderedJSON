import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - JSONPointer Tests

@Suite("JSONPointer init tests")
struct JSONPointerInitTests {
  @Test("pointer empty path") func pointerEmptyPath() throws {
    let ptr = try JSONPointer("")
    #expect(ptr.segments.isEmpty)
  }

  @Test("pointer single segment") func pointerSingleSegment() throws {
    let ptr = try JSONPointer("/foo")
    #expect(ptr.segments == ["foo"])
  }

  @Test("pointer multi segment") func pointerMultiSegment() throws {
    let ptr = try JSONPointer("/foo/bar/baz")
    #expect(ptr.segments == ["foo", "bar", "baz"])
  }

  @Test("pointer array index") func pointerArrayIndex() throws {
    let ptr = try JSONPointer("/0")
    #expect(ptr.segments == ["0"])
  }

  @Test("pointer escaping") func pointerEscaping() throws {
    let ptr = try JSONPointer("/a~1b")
    #expect(ptr.segments == ["a/b"])
  }

  @Test("pointer tilde escaping") func pointerTildeEscaping() throws {
    let ptr = try JSONPointer("/a~0b")
    #expect(ptr.segments == ["a~b"])
  }

  @Test("pointer tilde then slash escaping") func pointerTildeThenSlashEscaping() throws {
    // RFC 6901 §4: ~01 correctly becomes "~1" after transformation (not "/").
    // Order: ~1→/ first (no-op), then ~0→~ gives "~1".
    let ptr = try JSONPointer("/foo~01bar")
    #expect(ptr.segments == ["foo~1bar"])
  }

  @Test("pointer tilde then tilde escaping") func pointerTildeThenTildeEscaping() throws {
    // ~00 decodes as ~0→~ then literal 0 → "~0"
    // (RFC 6901's "~00 represents ~~" refers to escaping, not unescaping)
    let ptr = try JSONPointer("/foo~00bar")
    #expect(ptr.segments == ["foo~0bar"])
  }

  @Test("pointer no leading slash") func pointerNoLeadingSlash() throws {
    let error = #expect(throws: JSONPointerError.self) {
      try JSONPointer("foo")
    }
    #expect(error == .invalidSyntax("Pointer must start with '/' or be empty"))
  }

  @Test("pointer init segments") func pointerInitSegments() {
    let ptr = JSONPointer(segments: ["a", "b"])
    #expect(ptr.segments == ["a", "b"])
  }

  @Test("pointer leading zero allowed for zero") func pointerLeadingZeroAllowedForZero() throws {
    // "0" is valid per RFC 6901 ABNF (single digit zero)
    let ptr = try JSONPointer("/0")
    #expect(ptr.segments == ["0"])
  }

  @Test("pointer description root") func pointerDescriptionRoot() throws {
    let ptr = try JSONPointer("")
    #expect(ptr.description == "")
  }

  @Test("pointer description simple") func pointerDescriptionSimple() throws {
    let ptr = try JSONPointer("/foo/bar")
    #expect(ptr.description == "/foo/bar")
  }

  @Test("pointer description escaped") func pointerDescriptionEscaped() throws {
    let ptr = try JSONPointer("/a~1b/m~0n")
    #expect(ptr.description == "/a~1b/m~0n")
  }

  @Test("pointer description round trip") func pointerDescriptionRoundTrip() throws {
    let path = "/foo~01bar/~0baz"
    let ptr = try JSONPointer(path)
    // Description uses canonical ~1 encoding (not ~01), so round-trip is
    // semantically equivalent but syntactically different.
    let reparsed = try JSONPointer(ptr.description)
    #expect(reparsed.segments == ptr.segments)
  }
}

@Suite("JSONPointer resolve tests")
struct JSONPointerResolveTests {
  @Test("pointer resolve object") func pointerResolveObject() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let ptr = try JSONPointer("/foo")
    #expect(ptr.resolve(json) == JSON.string("bar"))
  }

  @Test("pointer resolve array") func pointerResolveArray() throws {
    let json = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    let ptr = try JSONPointer("/1")
    #expect(ptr.resolve(json) == JSON.number(.integer(1)))
  }

  @Test("pointer resolve nested") func pointerResolveNested() throws {
    let json = JSON.object(["a": JSON.object(["b": JSON.string("deep")])])
    let ptr = try JSONPointer("/a/b")
    #expect(ptr.resolve(json) == JSON.string("deep"))
  }

  @Test("pointer resolve empty path") func pointerResolveEmptyPath() throws {
    let json = JSON.string("root")
    let ptr = try JSONPointer("")
    #expect(ptr.resolve(json) == JSON.string("root"))
  }

  @Test("pointer resolve not found") func pointerResolveNotFound() throws {
    let json = JSON.object(["a": JSON.string("x")])
    let ptr = try JSONPointer("/missing")
    #expect(ptr.resolve(json) == nil)
  }

  @Test("pointer resolve bad index") func pointerResolveBadIndex() throws {
    let json = JSON.array([JSON.string("a")])
    let ptr = try JSONPointer("/5")
    #expect(ptr.resolve(json) == nil)
  }

  @Test("pointer resolve type mismatch") func pointerResolveTypeMismatch() throws {
    let json = JSON.string("scalar")
    let ptr = try JSONPointer("/foo")
    #expect(ptr.resolve(json) == nil)
  }

  @Test("pointer resolve dash token") func pointerResolveDashToken() throws {
    let json = JSON.array([JSON.string("a"), JSON.string("b")])
    let ptr = try JSONPointer("/-")
    // "-" refers to nonexistent element after last array element
    #expect(ptr.resolve(json) == nil)
  }

  @Test("pointer dash token on non array") func pointerDashTokenOnNonArray() throws {
    let json = JSON.object(["key": JSON.string("val")])
    let ptr = try JSONPointer("/-")
    // "-" on a non-array: resolve treats it as an object key (not found)
    #expect(ptr.resolve(json) == nil)
  }
}

@Suite("JSONPointer set tests")
struct JSONPointerSetTests {
  @Test("pointer set") func pointerSet() throws {
    var json = JSON.object(["a": JSON.string("old")])
    let ptr = try JSONPointer("/a")
    ptr.set(value: JSON.string("new"), into: &json)
    #expect(json["a"] == JSON.string("new"))
  }

  @Test("pointer set root") func pointerSetRoot() throws {
    var json = JSON.string("old")
    let ptr = try JSONPointer("")
    ptr.set(value: JSON.string("new"), into: &json)
    #expect(json == JSON.string("new"))
  }

  @Test("pointer set creates intermediate") func pointerSetCreatesIntermediate() throws {
    var json = JSON.object([:])
    let ptr = try JSONPointer("/a/b/c")
    ptr.set(value: JSON.string("deep"), into: &json)
    #expect(json["a"]?["b"]?["c"] == JSON.string("deep"))
  }

  @Test("pointer set creates array") func pointerSetCreatesArray() throws {
    var json = JSON.object([:])
    let ptr = try JSONPointer("/0")
    ptr.set(value: JSON.string("first"), into: &json)
    #expect(json.isArray)
    #expect(json[0] == JSON.string("first"))
  }

  @Test("pointer set dash appends to array") func pointerSetDashAppendsToArray() throws {
    var json = JSON.array([JSON.string("a")])
    let ptr = try JSONPointer("/-")
    ptr.set(value: JSON.string("b"), into: &json)
    #expect(json[0] == JSON.string("a"))
    #expect(json[1] == JSON.string("b"))
  }

  @Test("pointer set dash creates array") func pointerSetDashCreatesArray() throws {
    var json = JSON.object([:])  // start with object, "-" forces array
    let ptr = try JSONPointer("/-")
    ptr.set(value: JSON.string("first"), into: &json)
    #expect(json.isArray)
    #expect(json[0] == JSON.string("first"))
  }

  @Test("pointer set dash appends with rest") func pointerSetDashAppendsWithRest() throws {
    var json = JSON.array([JSON.object([:])])
    let ptr = try JSONPointer("/-/foo")
    ptr.set(value: JSON.string("bar"), into: &json)
    #expect(json[0]?.isObject == true)
    #expect(json[1]?.isObject == true)
    #expect(json[1]?["foo"] == JSON.string("bar"))
  }
}

@Suite("JSONPointer error tests")
struct JSONPointerErrorTests {
  @Test("pointer leading zero rejected") func pointerLeadingZeroRejected() throws {
    let error = #expect(throws: JSONPointerError.self) {
      try JSONPointer("/01")
    }
    #expect(error == .leadingZero("01"))
  }

  @Test("pointer leading zero rejected multi segment") func pointerLeadingZeroRejectedMultiSegment()
    throws
  {
    let error = #expect(throws: JSONPointerError.self) {
      try JSONPointer("/foo/01")
    }
    #expect(error == .leadingZero("01"))
  }
}

@Suite("JSONPointer fragment tests")
struct JSONPointerFragmentTests {
  @Test("pointer fragment init") func pointerFragmentInit() throws {
    let ptr = try JSONPointer(fragment: "#/foo/bar")
    #expect(ptr.segments == ["foo", "bar"])
  }

  @Test("pointer fragment init root") func pointerFragmentInitRoot() throws {
    let ptr = try JSONPointer(fragment: "#")
    #expect(ptr.segments.isEmpty)
  }

  @Test("pointer fragment init no hash") func pointerFragmentInitNoHash() throws {
    let error = #expect(throws: JSONPointerError.self) {
      try JSONPointer(fragment: "/foo")
    }
    #expect(error == .invalidSyntax("URI fragment must start with '#'"))
  }

  @Test("pointer fragment invalid percent encoding") func pointerFragmentInvalidPercentEncoding()
    throws
  {
    let error = #expect(throws: JSONPointerError.self) {
      try JSONPointer(fragment: "#/foo%GGbar")
    }
    #expect(error == .invalidSyntax("Invalid percent-encoding in URI fragment"))
  }

  @Test("pointer fragment percent decoded") func pointerFragmentPercentDecoded() throws {
    let ptr = try JSONPointer(fragment: "#/c%25d")
    #expect(ptr.segments == ["c%d"])
  }
}

@Suite("JSONPointer resolve or throw tests")
struct JSONPointerResolveOrThrowTests {
  @Test("resolve or throw success") func resolveOrThrowSuccess() throws {
    let json = JSON.object(["foo": JSON.string("bar")])
    let ptr = try JSONPointer("/foo")
    let value = try ptr.resolveOrThrow(json)
    #expect(value == JSON.string("bar"))
  }

  @Test("resolve or throw missing key") func resolveOrThrowMissingKey() throws {
    let json = JSON.object(["a": JSON.string("x")])
    let ptr = try JSONPointer("/missing")
    let error = #expect(throws: JSONPointerError.self) {
      try ptr.resolveOrThrow(json)
    }
    #expect(error == .missingValue("/missing"))
  }

  @Test("resolve or throw bad index") func resolveOrThrowBadIndex() throws {
    let json = JSON.array([JSON.string("a")])
    let ptr = try JSONPointer("/5")
    let error = #expect(throws: JSONPointerError.self) {
      try ptr.resolveOrThrow(json)
    }
    #expect(error == .missingValue("/5"))
  }

  @Test("resolve or throw type mismatch") func resolveOrThrowTypeMismatch() throws {
    let json = JSON.string("scalar")
    let ptr = try JSONPointer("/foo")
    let error = #expect(throws: JSONPointerError.self) {
      try ptr.resolveOrThrow(json)
    }
    #expect(error == .missingValue("/foo"))
  }

  @Test("resolve or throw dash token") func resolveOrThrowDashToken() throws {
    let json = JSON.array([JSON.string("a")])
    let ptr = try JSONPointer("/-")
    let error = #expect(throws: JSONPointerError.self) {
      try ptr.resolveOrThrow(json)
    }
    #expect(error == .missingValue("/-"))
  }
}

@Suite("JSONPointer flatten tests")
struct JSONPointerFlattenTests {
  @Test("unflatten simple") func unflattenSimple() throws {
    let flat = JSON.object([
      "/a": JSON.string("x"),
      "/b": JSON.number(.integer(1)),
    ])
    let result = try flat.unflatten()
    #expect(result.isObject)
    guard case .object(let dict) = result.storage else { return }
    #expect(dict["a"] == JSON.string("x"))
    #expect(dict["b"] == JSON.number(.integer(1)))
  }

  @Test("unflatten nested") func unflattenNested() throws {
    let flat = JSON.object([
      "/a/b/c": JSON.string("deep")
    ])
    let result = try flat.unflatten()
    #expect(result["a"]?["b"]?["c"] == JSON.string("deep"))
  }

  @Test("unflatten array indices") func unflattenArrayIndices() throws {
    let flat = JSON.object([
      "/0": JSON.string("a"),
      "/1": JSON.number(.integer(1)),
    ])
    let result = try flat.unflatten()
    #expect(result.isArray)
    #expect(result[0] == JSON.string("a"))
    #expect(result[1] == JSON.number(.integer(1)))
  }

  @Test("unflatten nested array") func unflattenNestedArray() throws {
    let flat = JSON.object([
      "/a/0": JSON.string("first"),
      "/a/1": JSON.number(.integer(2)),
    ])
    let result = try flat.unflatten()
    #expect(result["a"]?.isArray == true)
    #expect(result["a"]?[0] == JSON.string("first"))
    #expect(result["a"]?[1] == JSON.number(.integer(2)))
  }

  @Test("unflatten non object (throws)") func unflattenNonObjectThrows() throws {
    let scalar = JSON.string("hello")
    let error = #expect(throws: FlattenError.self) {
      try scalar.unflatten()
    }
    #expect(error == .notObject)
  }

  @Test("flatten and unflatten round trip") func flattenAndUnflattenRoundTrip() throws {
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
    let reconstructed = try flat.unflatten()
    #expect(reconstructed == original)
  }

  @Test("unflatten empty object") func unflattenEmptyObject() throws {
    // An empty input object unflattens to an empty object — not null.
    // The "empty containers → null" rule applies on the flatten side
    // only; unflatten does not apply a symmetric reverse.
    let flat = JSON.object([:])
    let result = try flat.unflatten()
    #expect(result.isObject)
    #expect(result.isEmpty)
  }

  @Test("unflatten array path without leading slash") func unflattenArrayPathWithoutLeadingSlash()
    throws
  {
    // Keys like "a/b/c" (without leading /) should still work
    let flat = JSON.object([
      "a": JSON.string("x")
    ])
    let result = try flat.unflatten()
    #expect(result.isObject)
    guard case .object(let dict) = result.storage else { return }
    #expect(dict["a"] == JSON.string("x"))
  }

  @Test("unflatten array with nested object") func unflattenArrayWithNestedObject() throws {
    // Path /0/foo: first segment "0" creates array from object root, rest not empty
    let flat = JSON.object([
      "/0/foo": JSON.string("bar")
    ])
    let result = try flat.unflatten()
    #expect(result.isArray)
    #expect(result[0]?.isObject == true)
    #expect(result[0]?["foo"] == JSON.string("bar"))
  }

  @Test("unflatten mixed array and object paths") func unflattenMixedArrayAndObjectPaths() throws {
    // First path /0 creates array root; second path /foo/bar overwrites root to object
    // (conflicting root types — last one wins)
    let flat = JSON.object([
      "/0": JSON.string("a"),
      "/foo/bar": JSON.string("b"),
    ])
    let result = try flat.unflatten()
    #expect(result.isObject)
    #expect(result["foo"]?.isObject == true)
    #expect(result["foo"]?["bar"] == JSON.string("b"))
  }
}
