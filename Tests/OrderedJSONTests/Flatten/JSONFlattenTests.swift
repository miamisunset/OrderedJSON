import Testing

@testable import OrderedJSON

// MARK: - Flatten tests (JSON Pointer format)

@Test func flattenEmptyObject() {
  let value = JSON.object([:])
  let result = value.flatten()
  #expect(result.isEmpty)
}

@Test func flattenString() throws {
  let value = JSON.string("hello")
  let result = value.flatten()
  guard case .object(let dict) = result.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict.count == 1)
  #expect(dict[""] == JSON.string("hello"))
}

@Test func flattenNumber() throws {
  let value = JSON.number(.integer(42))
  let result = value.flatten()
  guard case .object(let dict) = result.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict.count == 1)
  #expect(dict[""] == JSON.number(.integer(42)))
}

@Test func flattenBoolean() throws {
  let value = JSON.boolean(true)
  let result = value.flatten()
  guard case .object(let dict) = result.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict.count == 1)
  #expect(dict[""] == JSON.boolean(true))
}

@Test func flattenNull() throws {
  let value = JSON.null
  let result = value.flatten()
  guard case .object(let dict) = result.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict.count == 1)
  #expect(dict[""] == JSON.null)
}

@Test func flattenSingleLevelObject() throws {
  let value = JSON.object([
    "a": JSON.string("x"),
    "b": JSON.number(.integer(1)),
  ])
  let result = value.flatten()
  guard case .object(let dict) = result.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict.count == 2)
  #expect(dict["/a"] == JSON.string("x"))
  #expect(dict["/b"] == JSON.number(.integer(1)))
}

@Test func flattenNestedObject() throws {
  let value = JSON.object([
    "a": JSON.object([
      "b": JSON.object([
        "c": JSON.string("deep")
      ])
    ])
  ])
  let result = value.flatten()
  guard case .object(let dict) = result.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict.count == 1)
  #expect(dict["/a/b/c"] == JSON.string("deep"))
}

@Test func flattenArray() throws {
  let value = JSON.array([
    JSON.string("a"),
    JSON.number(.integer(2)),
    JSON.boolean(true),
  ])
  let result = value.flatten()
  guard case .object(let dict) = result.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict.count == 3)
  #expect(dict["/0"] == JSON.string("a"))
  #expect(dict["/1"] == JSON.number(.integer(2)))
  #expect(dict["/2"] == JSON.boolean(true))
}

@Test func flattenMixedNested() throws {
  let value = JSON.object([
    "a": JSON.array([
      JSON.number(.integer(1)),
      JSON.object([
        "b": JSON.string("nested")
      ]),
    ])
  ])
  let result = value.flatten()
  guard case .object(let dict) = result.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict.count == 2)
  #expect(dict["/a/0"] == JSON.number(.integer(1)))
  #expect(dict["/a/1/b"] == JSON.string("nested"))
}

@Test func flattenNestedArrayInArray() throws {
  let value = JSON.array([
    JSON.array([
      JSON.string("x"),
      JSON.string("y"),
    ]),
    JSON.string("z"),
  ])
  let result = value.flatten()
  guard case .object(let dict) = result.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict.count == 3)
  #expect(dict["/0/0"] == JSON.string("x"))
  #expect(dict["/0/1"] == JSON.string("y"))
  #expect(dict["/1"] == JSON.string("z"))
}

@Test func flattenKeyWithSlash() throws {
  // Keys containing / must be escaped as ~1
  let json = JSON.object([
    "a/b": .number(.integer(1)),
    "c": .number(.integer(2)),
  ])
  let flat = json.flatten()
  guard case .object(let dict) = flat.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict["/a~1b"] == JSON.number(.integer(1)))
  #expect(dict["/c"] == JSON.number(.integer(2)))
}

@Test func flattenKeyWithTilde() throws {
  // Keys containing ~ must be escaped as ~0
  let json = JSON.object(["a~b": .number(.integer(1))])
  let flat = json.flatten()
  guard case .object(let dict) = flat.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict["/a~0b"] == JSON.number(.integer(1)))
}

@Test func flattenKeyWithTildeAndSlash() throws {
  // Keys containing ~ and / must escape both
  let json = JSON.object(["a~/b": .number(.integer(1))])
  let flat = json.flatten()
  guard case .object(let dict) = flat.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict["/a~0~1b"] == JSON.number(.integer(1)))
}

@Test func unflattenEscapedKeys() throws {
  // Round-trip: flatten with special chars → unflatten preserves values
  let original = JSON.object([
    "a/b": .number(.integer(1)),
    "a~b": .number(.integer(2)),
    "a~/b": .number(.integer(3)),
  ])
  let flat = original.flatten()
  let unflattened = flat.unflatten()
  // Verify each key has the correct value (order may differ)
  guard case .object(let dict) = unflattened.storage else {
    Issue.record("Expected object")
    return
  }
  #expect(dict["a/b"] == JSON.number(.integer(1)))
  #expect(dict["a~b"] == JSON.number(.integer(2)))
  #expect(dict["a~/b"] == JSON.number(.integer(3)))
}
