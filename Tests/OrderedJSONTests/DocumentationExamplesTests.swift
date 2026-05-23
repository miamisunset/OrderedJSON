import Foundation
import Testing

@testable import OrderedJSON

// MARK: - Creating Values (README)

@Test func docCreatingValues() {
  // Primitives
  let stringVal = JSONValue.string("hello")
  let numberVal = JSONValue.number(.integer(42))
  let floatVal = JSONValue.number(.float(3.14))
  let boolVal = JSONValue.boolean(true)
  let nullVal = JSONValue.null

  #expect(stringVal == JSONValue.string("hello"))
  #expect(numberVal == JSONValue.number(.integer(42)))
  #expect(floatVal == JSONValue.number(.float(3.14)))
  #expect(boolVal == JSONValue.boolean(true))
  #expect(nullVal == JSONValue.null)

  // Arrays
  let arrayVal = JSONValue.array([
    .string("a"),
    .number(.integer(1)),
    .boolean(false),
    .null,
  ])

  #expect(
    arrayVal
      == JSONValue.array([
        .string("a"),
        .number(.integer(1)),
        .boolean(false),
        .null,
      ]))

  // Objects (keys preserve insertion order)
  let objectVal = JSONValue.object([
    "name": .string("Alice"),
    "age": .number(.integer(30)),
    "city": .string("New York"),
  ])

  guard case .object(let dict) = objectVal else {
    Issue.record("Expected object")
    return
  }
  #expect(dict.keys == ["name", "age", "city"])
}

// MARK: - Flatten (README)

@Test func docFlatten() {
  let value = JSONValue.object([
    "a": .string("x"),
    "b": .object([
      "c": .string("deep")
    ]),
    "d": .array([
      .number(.integer(1)),
      .object([
        "e": .string("nested")
      ]),
    ]),
  ])

  let flat = value.flatten()
  #expect(flat.count == 4)
  #expect(flat[0].key == "a")
  #expect(flat[0].value == JSONValue.string("x"))
  #expect(flat[1].key == "b.c")
  #expect(flat[1].value == JSONValue.string("deep"))
  #expect(flat[2].key == "d[0]")
  #expect(flat[2].value == JSONValue.number(.integer(1)))
  #expect(flat[3].key == "d[1].e")
  #expect(flat[3].value == JSONValue.string("nested"))
}

@Test func docFlattenScalars() {
  let scalar = JSONValue.string("hello")
  let result = scalar.flatten()
  // result[0].key   == ""
  // result[0].value == JSONValue.string("hello")
  #expect(result.count == 1)
  #expect(result[0].key == "")
  #expect(result[0].value == JSONValue.string("hello"))
}

@Test func docFlattenArrays() {
  let array = JSONValue.array([
    .string("a"),
    .number(.integer(2)),
    .boolean(true),
  ])
  let flat = array.flatten()
  // flat[0].key == "[0]"
  // flat[1].key == "[1]"
  // flat[2].key == "[2]"
  #expect(flat.count == 3)
  #expect(flat[0].key == "[0]")
  #expect(flat[1].key == "[1]")
  #expect(flat[2].key == "[2]")
}

@Test func docFlattenEmptyObjects() {
  let empty = JSONValue.object([:])
  let result = empty.flatten()
  // result.isEmpty == true
  #expect(result.isEmpty)
}

// MARK: - Quick Start (README)

@Test func docQuickStart() throws {
  let json = """
    {"z": 1, "a": 2, "m": 3}
    """
  let value = try JSONValue.parse(json)

  guard case .object(let dict) = value else {
    Issue.record("Expected object")
    return
  }
  #expect(Array(dict.keys) == ["z", "a", "m"])

  let flat = value.flatten()
  #expect(flat.count == 3)
  #expect(flat[0].key == "z")
  #expect(flat[0].value == JSONValue.number(.integer(1)))
  #expect(flat[1].key == "a")
  #expect(flat[1].value == JSONValue.number(.integer(2)))
  #expect(flat[2].key == "m")
  #expect(flat[2].value == JSONValue.number(.integer(3)))
}

// MARK: - Parsing JSON from a String (README)

@Test func docParseFromString() throws {
  let jsonString = """
    {"c": 3, "a": 1, "b": 2}
    """
  let parsed = try JSONValue.parse(jsonString)
  guard case .object(let dict) = parsed else {
    Issue.record("Expected object")
    return
  }
  #expect(Array(dict.keys) == ["c", "a", "b"])
}

// MARK: - Standard JSON Encoding (README)

@Test func docStandardEncoding() throws {
  let value = JSONValue.object([
    "name": .string("Bob"),
    "age": .number(.integer(25)),
  ])

  let standardData = try value.encodeStandard()
  let json = String(data: standardData, encoding: .utf8)
  #expect(json == "{\"name\":\"Bob\",\"age\":25}")
}

// MARK: - Round-Trip Nested JSON (README)

@Test func docNestedRoundTrip() throws {
  let input = """
    {"a": {"b": 1, "c": [2, {"d": 3}]}}
    """
  // Use parse() for order-preserving first decode
  let value = try JSONValue.parse(input)
  let encoded = try value.encodeStandard()
  let decoded = try JSONValue.parse(String(data: encoded, encoding: .utf8)!)

  // Verify structure and order are preserved through round trip
  guard case .object(let outer) = decoded else {
    Issue.record("Expected outer object")
    return
  }
  #expect(Array(outer.keys) == ["a"])
  guard case .object(let inner) = outer["a"]! else {
    Issue.record("Expected inner object")
    return
  }
  #expect(Array(inner.keys) == ["b", "c"])
  #expect(inner["b"] == JSONValue.number(.integer(1)))
  guard case .array(let arr) = inner["c"]! else {
    Issue.record("Expected array")
    return
  }
  #expect(arr.count == 2)
  #expect(arr[0] == JSONValue.number(.integer(2)))
  guard case .object(let deep) = arr[1] else {
    Issue.record("Expected deep object")
    return
  }
  #expect(Array(deep.keys) == ["d"])
  #expect(deep["d"] == JSONValue.number(.integer(3)))
}

// MARK: - Round-Trip Exact Order (README — parse, modify, re-encode as standard JSON)

@Test func docRoundTripExactOrder() throws {
  let input = """
    {"z": 1, "a": 2, "m": 3}
    """
  let value = try JSONValue.parse(input)

  // Modify a value
  guard case .object(var dict) = value else {
    Issue.record("Expected object")
    return
  }
  dict["a"] = .number(.integer(99))
  let modified = JSONValue.object(dict)

  // Encode back to standard JSON
  let output = String(data: try modified.encodeStandard(), encoding: .utf8)!
  // Output should have same key order, updated values
  #expect(output == "{\"z\":1,\"a\":99,\"m\":3}")
}

@Test func docRoundTripNestedExactOrder() throws {
  let input = """
    {"a": {"b": 1, "c": [2, {"d": 3}]}}
    """
  let value = try JSONValue.parse(input)

  // Modify a deeply nested value
  guard case .object(var dict) = value else {
    Issue.record("Expected object")
    return
  }
  guard case .object(var inner) = dict["a"]! else {
    Issue.record("Expected inner object")
    return
  }
  inner["b"] = .number(.integer(99))
  dict["a"] = .object(inner)
  let modified = JSONValue.object(dict)

  let output = String(data: try modified.encodeStandard(), encoding: .utf8)!
  // Same key order, updated value
  #expect(output == "{\"a\":{\"b\":99,\"c\":[2,{\"d\":3}]}}")
}

// MARK: - Key Order Preservation (README)

@Test func docKeyOrderPreservation() throws {
  let original = JSONValue.object([
    "z": .number(.integer(1)),
    "a": .number(.integer(2)),
    "m": .number(.integer(3)),
  ])

  let data = try original.encodeStandard()
  let decoded = try JSONValue.parse(String(data: data, encoding: .utf8)!)

  guard case .object(let dict) = decoded else {
    Issue.record("Expected object")
    return
  }
  let keys = Array(dict.keys)
  // keys == ["z", "a", "m"]  — order is preserved
  #expect(keys == ["z", "a", "m"])
}
