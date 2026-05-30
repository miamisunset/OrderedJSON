import Testing

@testable import OrderedJSON

// MARK: - Flatten tests (JSON Pointer format)

@Suite("Flatten Tests") struct JSONFlattenTests {
  @Test("flatten empty object") func flattenEmptyObject() {
    let value = JSON.object([:])
    let result = value.flatten()
    // Empty objects flatten to null (matching nlohmann/json behavior)
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.count == 1)
    #expect(dict[""] == JSON.null)
  }

  @Test("flatten empty array") func flattenEmptyArray() {
    let value = JSON.array([])
    let result = value.flatten()
    // Empty arrays flatten to null (matching nlohmann/json behavior)
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.count == 1)
    #expect(dict[""] == JSON.null)
  }

  @Test("flatten nested empty object") func flattenNestedEmptyObject() {
    let value = JSON.object([
      "a": .object([:])
    ])
    let result = value.flatten()
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict["/a"] == JSON.null)
  }

  @Test("flatten nested empty array") func flattenNestedEmptyArray() {
    let value = JSON.object([
      "a": .array([])
    ])
    let result = value.flatten()
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict["/a"] == JSON.null)
  }

  @Test("flatten string") func flattenString() {
    let value = JSON.string("hello")
    let result = value.flatten()
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.count == 1)
    #expect(dict[""] == JSON.string("hello"))
  }

  @Test("flatten number") func flattenNumber() {
    let value = JSON.number(.integer(42))
    let result = value.flatten()
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.count == 1)
    #expect(dict[""] == JSON.number(.integer(42)))
  }

  @Test("flatten boolean") func flattenBoolean() {
    let value = JSON.boolean(true)
    let result = value.flatten()
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.count == 1)
    #expect(dict[""] == JSON.boolean(true))
  }

  @Test("flatten null") func flattenNull() {
    let value = JSON.null
    let result = value.flatten()
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.count == 1)
    #expect(dict[""] == JSON.null)
  }

  @Test("flatten single level object") func flattenSingleLevelObject() {
    let value = JSON.object([
      "a": JSON.string("x"),
      "b": JSON.number(.integer(1)),
    ])
    let result = value.flatten()
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.count == 2)
    #expect(dict["/a"] == JSON.string("x"))
    #expect(dict["/b"] == JSON.number(.integer(1)))
  }

  @Test("flatten nested object") func flattenNestedObject() {
    let value = JSON.object([
      "a": JSON.object([
        "b": JSON.object([
          "c": JSON.string("deep")
        ])
      ])
    ])
    let result = value.flatten()
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.count == 1)
    #expect(dict["/a/b/c"] == JSON.string("deep"))
  }

  @Test("flatten array") func flattenArray() {
    let value = JSON.array([
      JSON.string("a"),
      JSON.number(.integer(2)),
      JSON.boolean(true),
    ])
    let result = value.flatten()
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.count == 3)
    #expect(dict["/0"] == JSON.string("a"))
    #expect(dict["/1"] == JSON.number(.integer(2)))
    #expect(dict["/2"] == JSON.boolean(true))
  }

  @Test("flatten mixed nested") func flattenMixedNested() {
    let value = JSON.object([
      "a": JSON.array([
        JSON.number(.integer(1)),
        JSON.object([
          "b": JSON.string("nested")
        ]),
      ])
    ])
    let result = value.flatten()
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.count == 2)
    #expect(dict["/a/0"] == JSON.number(.integer(1)))
    #expect(dict["/a/1/b"] == JSON.string("nested"))
  }

  @Test("flatten nested array in array") func flattenNestedArrayInArray() {
    let value = JSON.array([
      JSON.array([
        JSON.string("x"),
        JSON.string("y"),
      ]),
      JSON.string("z"),
    ])
    let result = value.flatten()
    #expect(result.isObject, "Expected object")
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.count == 3)
    #expect(dict["/0/0"] == JSON.string("x"))
    #expect(dict["/0/1"] == JSON.string("y"))
    #expect(dict["/1"] == JSON.string("z"))
  }
}

@Suite("Unflatten Tests") struct JSONUnflattenTests {
  @Test("unflatten escaped keys") func unflattenEscapedKeys() throws {
    // Round-trip: flatten with special chars → unflatten preserves values
    let original = JSON.object([
      "a/b": .number(.integer(1)),
      "a~b": .number(.integer(2)),
      "a~/b": .number(.integer(3)),
    ])
    let flat = original.flatten()
    let unflattened = try flat.unflatten()
    // Verify each key has the correct value (order may differ)
    #expect(unflattened.isObject, "Expected object")
    guard case .object(let dict) = unflattened.storage else { return }
    #expect(dict["a/b"] == JSON.number(.integer(1)))
    #expect(dict["a~b"] == JSON.number(.integer(2)))
    #expect(dict["a~/b"] == JSON.number(.integer(3)))
  }

  @Test("flatten unflatten round trip with empty containers")
  func flattenUnflattenRoundTripWithEmptyContainers() throws {
    // Empty arrays/objects flatten to null; round-trip preserves the null
    let original = JSON.object([
      "emptyObj": .object([:]),
      "emptyArr": .array([]),
    ])
    let flat = original.flatten()
    let reconstructed = try flat.unflatten()
    // Empty containers become null after round-trip
    #expect(reconstructed.isObject, "Expected object")
    guard case .object(let dict) = reconstructed.storage else { return }
    #expect(dict["emptyObj"] == JSON.null)
    #expect(dict["emptyArr"] == JSON.null)
  }

  @Test("flatten unflatten non object throws") func flattenUnflattenNonObjectThrows() throws {
    let scalar = JSON.string("hello")
    #expect {
      _ = try scalar.unflatten()
    } throws: { error in
      guard let flattenErr = error as? FlattenError else { return false }
      if case .notObject = flattenErr { return true }
      return false
    }
  }

  @Test("unflatten non primitive value throws") func unflattenNonPrimitiveValueThrows() throws {
    let flat = JSON.object([
      "/a": .object(["b": .string("nested")])
    ])
    #expect {
      _ = try flat.unflatten()
    } throws: { error in
      guard let flattenErr = error as? FlattenError else { return false }
      if case .notPrimitive(let key, let type) = flattenErr {
        return key == "/a" && type == "object"
      }
      return false
    }
  }
}

