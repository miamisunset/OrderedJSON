import Testing

@testable import OrderedJSON

// MARK: - Flatten Edge Case Tests

@Suite("Flatten Edge Case Tests") struct JSONFlattenEdgeCaseTests {
  // MARK: - Key escaping round-trip

  @Test("key ~ round-trip") func keyTildeRoundTrip() throws {
    let original = JSON.object(["~": .number(.integer(1))])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    guard case .object(let dict) = reconstructed.storage else { return }
    #expect(dict["~"] == JSON.number(.integer(1)))
  }

  @Test("key ~0 round-trip") func keyTilde0RoundTrip() throws {
    let original = JSON.object(["~0": .number(.integer(1))])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    guard case .object(let dict) = reconstructed.storage else { return }
    #expect(dict["~0"] == JSON.number(.integer(1)))
  }

  @Test("key ~1 round-trip") func keyTilde1RoundTrip() throws {
    let original = JSON.object(["~1": .number(.integer(1))])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    guard case .object(let dict) = reconstructed.storage else { return }
    #expect(dict["~1"] == JSON.number(.integer(1)))
  }

  @Test("key ~01 round-trip") func keyTilde01RoundTrip() throws {
    let original = JSON.object(["~01": .number(.integer(1))])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    guard case .object(let dict) = reconstructed.storage else { return }
    #expect(dict["~01"] == JSON.number(.integer(1)))
  }

  @Test("key ~10 round-trip") func keyTilde10RoundTrip() throws {
    let original = JSON.object(["~10": .number(.integer(1))])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    guard case .object(let dict) = reconstructed.storage else { return }
    #expect(dict["~10"] == JSON.number(.integer(1)))
  }

  @Test("key ~0~1 round-trip") func keyTilde0Tilde1RoundTrip() throws {
    let original = JSON.object(["~0~1": .number(.integer(1))])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    guard case .object(let dict) = reconstructed.storage else { return }
    #expect(dict["~0~1"] == JSON.number(.integer(1)))
  }

  @Test("key / round-trip") func keySlashRoundTrip() throws {
    let original = JSON.object(["/": .number(.integer(1))])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    guard case .object(let dict) = reconstructed.storage else { return }
    #expect(dict["/"] == JSON.number(.integer(1)))
  }

  @Test("key a~0b round-trip") func keyLiteralTilde0RoundTrip() throws {
    let original = JSON.object(["a~0b": .number(.integer(1))])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    guard case .object(let dict) = reconstructed.storage else { return }
    #expect(dict["a~0b"] == JSON.number(.integer(1)))
  }

  @Test("key a~01b round-trip") func keyLiteralTilde01RoundTrip() throws {
    let original = JSON.object(["a~01b": .number(.integer(1))])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    guard case .object(let dict) = reconstructed.storage else { return }
    #expect(dict["a~01b"] == JSON.number(.integer(1)))
  }

  @Test("multiple special keys round-trip") func multipleSpecialKeysRoundTrip() throws {
    let original = JSON.object([
      "~": .number(.integer(1)),
      "/": .number(.integer(2)),
      "~0": .number(.integer(3)),
      "~1": .number(.integer(4)),
      "~01": .number(.integer(5)),
    ])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    guard case .object(let dict) = reconstructed.storage else { return }
    #expect(dict["~"] == JSON.number(.integer(1)))
    #expect(dict["/"] == JSON.number(.integer(2)))
    #expect(dict["~0"] == JSON.number(.integer(3)))
    #expect(dict["~1"] == JSON.number(.integer(4)))
    #expect(dict["~01"] == JSON.number(.integer(5)))
  }

  @Test("nested special keys round-trip") func nestedSpecialKeysRoundTrip() throws {
    let original = JSON.object([
      "outer": .object([
        "~": .number(.integer(1)),
        "/": .number(.integer(2)),
        "~0": .number(.integer(3)),
        "~1": .number(.integer(4)),
      ])
    ])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed["outer"]?["~"] == JSON.number(.integer(1)))
    #expect(reconstructed["outer"]?["/"] == JSON.number(.integer(2)))
    #expect(reconstructed["outer"]?["~0"] == JSON.number(.integer(3)))
    #expect(reconstructed["outer"]?["~1"] == JSON.number(.integer(4)))
  }

  // MARK: - Empty containers round-trip

  @Test("empty object round-trip") func emptyObjectRoundTrip() throws {
    let original = JSON.object(["key": .object([:])])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    // Empty object becomes null after flatten→unflatten
    #expect(reconstructed["key"] == JSON.null)
  }

  @Test("empty array round-trip") func emptyArrayRoundTrip() throws {
    let original = JSON.object(["key": .array([])])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    // Empty array becomes null after flatten→unflatten
    #expect(reconstructed["key"] == JSON.null)
  }

  @Test("nested empty containers at multiple levels") func nestedEmptyContainers() throws {
    let original = JSON.object([
      "a": .object([:]),       // empty object
      "b": .array([]),         // empty array
      "c": .object([           // non-empty with nested empties
        "x": .object([:]),
        "y": .array([]),
      ]),
    ])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isObject)
    #expect(reconstructed["a"] == JSON.null)
    #expect(reconstructed["b"] == JSON.null)
    #expect(reconstructed["c"]?.isObject == true)
    #expect(reconstructed["c"]?["x"] == JSON.null)
    #expect(reconstructed["c"]?["y"] == JSON.null)
  }

  // MARK: - Root-only scalar round-trip

  @Test("null root round-trip") func nullRootRoundTrip() throws {
    let flat = JSON.null.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed == JSON.null)
  }

  @Test("boolean root round-trip") func booleanRootRoundTrip() throws {
    let flat = JSON.boolean(true).flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed == JSON.boolean(true))
  }

  @Test("number root round-trip") func numberRootRoundTrip() throws {
    let flat = JSON.number(.integer(42)).flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed == JSON.number(.integer(42)))
  }

  @Test("string root round-trip") func stringRootRoundTrip() throws {
    let flat = JSON.string("hello").flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed == JSON.string("hello"))
  }

  @Test("float root round-trip") func floatRootRoundTrip() throws {
    let flat = JSON.number(.float(3.14)).flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed == JSON.number(.float(3.14)))
  }

  // MARK: - Non-primitive validation

  @Test("unflatten with nested object value throws") func unflattenNestedObjectValueThrows() throws {
    let flat = JSON.object([
      "/a": .object(["b": .string("nested")])
    ])
    #expect {
      _ = try flat.unflatten()
    } throws: { error in
      guard let e = error as? FlattenError else { return false }
      if case .notPrimitive(let key, let type) = e {
        return key == "/a" && type == "object"
      }
      return false
    }
  }

  @Test("unflatten with array value throws") func unflattenArrayValueThrows() throws {
    let flat = JSON.object([
      "/a": .array([.string("x")])
    ])
    #expect {
      _ = try flat.unflatten()
    } throws: { error in
      guard let e = error as? FlattenError else { return false }
      if case .notPrimitive(let key, let type) = e {
        return key == "/a" && type == "array"
      }
      return false
    }
  }

  @Test("unflatten not object throws") func unflattenNotObjectThrows() throws {
    let error = #expect(throws: FlattenError.self) {
      try JSON.array([.string("x")]).unflatten()
    }
    #expect(error == .notObject)
  }

  // MARK: - Deep nesting

  @Test("deeply nested round-trip") func deeplyNestedRoundTrip() throws {
    let json = JSON.object(["level0": .number(.integer(0))])
    var current = json
    for i in 1...50 {
      let next = JSON.object([
        "level\(i)": current
      ])
      current = next
    }
    // current is now a 50-level-deep nested object
    let flat = current.flatten()
    let reconstructed = try flat.unflatten()
    // Verify we can reach the leaf value
    #expect(reconstructed["level50"]?.isObject == true)
  }

  // MARK: - Array with numeric-like keys

  @Test("object with numeric keys round-trip") func objectWithNumericKeysRoundTrip() throws {
    // Keys that look like array indices are treated as array indices during
    // unflatten (matching nlohmann/json behavior)
    let original = JSON.object([
      "0": .string("zero"),
      "1": .string("one"),
      "2": .string("two"),
    ])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    // Numeric keys cause unflatten to build an array instead of an object
    #expect(reconstructed.isArray)
    guard case .array(let arr) = reconstructed.storage else { return }
    #expect(arr.count == 3)
    #expect(arr[0] == JSON.string("zero"))
    #expect(arr[1] == JSON.string("one"))
    #expect(arr[2] == JSON.string("two"))
  }

  @Test("array round-trip preserves order") func arrayRoundTripPreservesOrder() throws {
    let original = JSON.array([
      .number(.integer(1)),
      .number(.integer(2)),
      .number(.integer(3)),
    ])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    #expect(reconstructed.isArray)
    guard case .array(let arr) = reconstructed.storage else { return }
    #expect(arr.count == 3)
    #expect(arr[0] == JSON.number(.integer(1)))
    #expect(arr[1] == JSON.number(.integer(2)))
    #expect(arr[2] == JSON.number(.integer(3)))
  }
}

// MARK: - JSONPointer Edge Case Tests

@Suite("JSONPointer Edge Case Tests") struct JSONPointerEdgeCaseTests {
  @Test("pointer description round-trip for various segments")
  func pointerDescriptionRoundTripVarious() throws {
    let paths: [(String, [String])] = [
      ("/foo", ["foo"]),
      ("/foo/bar", ["foo", "bar"]),
      ("/a~1b", ["a/b"]),
      ("/a~0b", ["a~b"]),
      ("/foo~01bar", ["foo~1bar"]),
      ("/foo~00bar", ["foo~0bar"]),
      ("/", [""]),           // single empty segment
      ("/a//c", ["a", "", "c"]),  // empty middle segment
    ]
    for (path, expectedSegments) in paths {
      let ptr = try JSONPointer(path)
      #expect(ptr.segments == expectedSegments, "For path \(path)")
      // Description should round-trip: parse → describe → parse → same segments
      let reparsed = try JSONPointer(ptr.description)
      #expect(reparsed.segments == ptr.segments, "Description round-trip for \(path)")
    }
  }

  @Test("pointer resolve empty array") func pointerResolveEmptyArray() throws {
    let json = JSON.array([])
    let ptr = try JSONPointer("/0")
    #expect(ptr.resolve(json) == nil)
  }

  @Test("pointer resolve negative index") func pointerResolveNegativeIndex() throws {
    let json = JSON.array([.string("a"), .string("b")])
    let ptr = try JSONPointer("/-1")
    // -1 is not a valid array index per RFC 6901 (non-negative only)
    #expect(ptr.resolve(json) == nil)
  }

  @Test("pointer resolve dash on non-array") func pointerResolveDashOnNonArray() throws {
    let json = JSON.object(["key": .string("val")])
    let ptr = try JSONPointer("/-")
    // "-" on non-array: resolve treats it as an object key → not found
    #expect(ptr.resolve(json) == nil)
  }

  @Test("pointer set index equal to count appends") func pointerSetIndexEqualToCount() throws {
    var json = JSON.array([.string("a"), .string("b")])
    let ptr = try JSONPointer("/2")  // index == count
    ptr.set(value: .string("c"), into: &json)
    #expect(json.isArray)
    #expect(json[0] == .string("a"))
    #expect(json[1] == .string("b"))
    #expect(json[2] == .string("c"))
  }

  @Test("pointer set index beyond count pads with null") func pointerSetIndexBeyondCount() throws {
    var json = JSON.array([.string("a")])
    let ptr = try JSONPointer("/3")
    ptr.set(value: .string("d"), into: &json)
    #expect(json.isArray)
    #expect(json[0] == .string("a"))
    #expect(json[1] == .null)
    #expect(json[2] == .null)
    #expect(json[3] == .string("d"))
  }

  @Test("pointer set dash on non-array creates array") func pointerSetDashOnNonArray() throws {
    var json = JSON.object(["keep": .string("me")])
    let ptr = try JSONPointer("/-")
    ptr.set(value: .string("appended"), into: &json)
    // Dash on non-array replaces entire value with an array
    #expect(json.isArray)
    #expect(json[0] == .string("appended"))
  }

  @Test("pointer set dash with nested rest on non-array")
  func pointerSetDashWithNestedRestOnNonArray() throws {
    var json = JSON.object(["keep": .string("me")])
    let ptr = try JSONPointer("/-/foo/bar")
    ptr.set(value: .string("deep"), into: &json)
    // Dash on non-array creates array with one object element
    #expect(json.isArray)
    #expect(json[0]?.isObject == true)
    #expect(json[0]?["foo"]?.isObject == true)
    #expect(json[0]?["foo"]?["bar"] == .string("deep"))
  }

  @Test("pointer set with empty segment") func pointerSetEmptySegment() throws {
    var json = JSON.object(["a": .string("x")])
    // Path "/a/" has an empty segment after "a"
    let ptr = try JSONPointer("/a/")
    ptr.set(value: .string("child"), into: &json)
    // Empty segment is treated as an object key ""
    #expect(json["a"]?.isObject == true)
    #expect(json["a"]?[""] == .string("child"))
  }

  @Test("leading zero with non-ASCII digits allowed")
  func leadingZeroNonAsciiDigits() throws {
    // Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩) should not trigger leading-zero check
    // since RFC 6901 ABNF specifies ASCII digits only
    let ptr = try JSONPointer("/foo/١")  // Arabic-Indic digit
    // Should not throw leadingZero — it's not an ASCII digit
    #expect(ptr.segments == ["foo", "١"])
  }

  @Test("pointer resolveOrThrow with empty array")
  func pointerResolveOrThrowEmptyArray() throws {
    let json = JSON.array([])
    let ptr = try JSONPointer("/0")
    let error = #expect(throws: JSONPointerError.self) {
      try ptr.resolveOrThrow(json)
    }
    #expect(error == .missingValue("/0"))
  }

  @Test("pointer resolveOrThrow with negative index")
  func pointerResolveOrThrowNegativeIndex() throws {
    let json = JSON.array([.string("a")])
    let ptr = try JSONPointer("/-1")
    let error = #expect(throws: JSONPointerError.self) {
      try ptr.resolveOrThrow(json)
    }
    #expect(error == .missingValue("/-1"))
  }

  // MARK: - Fragment edge cases

  @Test("fragment with percent-encoded tilde")
  func fragmentPercentEncodedTilde() throws {
    // %7E is percent-encoded ~
    let ptr = try JSONPointer(fragment: "#/foo/%7Ebar")
    #expect(ptr.segments == ["foo", "~bar"])
  }

  @Test("fragment with percent-encoded slash becomes separator")
  func fragmentPercentEncodedSlash() throws {
    // %2F decodes to /, which is then treated as a path separator
    let ptr = try JSONPointer(fragment: "#/foo%2Fbar")
    #expect(ptr.segments == ["foo", "bar"])
  }

  @Test("fragment with percent-encoded ~0 sequence")
  func fragmentPercentEncodedTilde0() throws {
    // %7E0 → ~0 after percent-decoding, then unescaped as ~
    let ptr = try JSONPointer(fragment: "#/a%7E0b")
    #expect(ptr.segments == ["a~b"])
  }

  // MARK: - unflatten with alternative key formats

  @Test("unflatten with keys without leading slash")
  func unflattenWithoutLeadingSlash() throws {
    let flat = JSON.object([
      "a/b": .string("nested"),
      "a/c": .number(.integer(1)),
    ])
    let result = try flat.unflatten()
    #expect(result.isObject)
    #expect(result["a"]?.isObject == true)
    #expect(result["a"]?["b"] == .string("nested"))
    #expect(result["a"]?["c"] == .number(.integer(1)))
  }

  @Test("unflatten with root pointer key")
  func unflattenWithRootPointerKey() throws {
    // The key "" (empty string) represents the root pointer
    let flat = JSON.object([
      "": .string("root value"),
      "/a": .number(.integer(1)),
    ])
    let result = try flat.unflatten()
    #expect(result.isObject)
    #expect(result["a"] == .number(.integer(1)))
    // The root value replaces the entire object when "" key is present
  }

  @Test("unflatten with single root pointer key")
  func unflattenSingleRootPointerKey() throws {
    // Only the "" key — should replace root with the value
    let flat = JSON.object([
      "": .number(.integer(42))
    ])
    let result = try flat.unflatten()
    #expect(result == .number(.integer(42)))
  }
}
