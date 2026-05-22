import Foundation
import Testing

@testable import OrderedJSON

// MARK: - Flatten tests

@Test func flattenEmptyObject() {
  let value = JSONValue.object([:])
  let result = value.flatten()
  #expect(result.isEmpty)
}

@Test func flattenString() {
  let value = JSONValue.string("hello")
  let result = value.flatten()
  #expect(result.count == 1)
  #expect(result[0].key == "")
  #expect(result[0].value == JSONValue.string("hello"))
}

@Test func flattenNumber() {
  let value = JSONValue.number(.integer(42))
  let result = value.flatten()
  #expect(result.count == 1)
  #expect(result[0].key == "")
  #expect(result[0].value == JSONValue.number(.integer(42)))
}

@Test func flattenBoolean() {
  let value = JSONValue.boolean(true)
  let result = value.flatten()
  #expect(result.count == 1)
  #expect(result[0].key == "")
  #expect(result[0].value == JSONValue.boolean(true))
}

@Test func flattenNull() {
  let value = JSONValue.null
  let result = value.flatten()
  #expect(result.count == 1)
  #expect(result[0].key == "")
  #expect(result[0].value == JSONValue.null)
}

@Test func flattenSingleLevelObject() {
  let value = JSONValue.object([
    "a": .string("x"),
    "b": .number(.integer(1)),
  ])
  let result = value.flatten()
  #expect(result.count == 2)
  #expect(result[0].key == "a")
  #expect(result[0].value == JSONValue.string("x"))
  #expect(result[1].key == "b")
  #expect(result[1].value == JSONValue.number(.integer(1)))
}

@Test func flattenNestedObject() {
  let value = JSONValue.object([
    "a": .object([
      "b": .object([
        "c": .string("deep")
      ])
    ])
  ])
  let result = value.flatten()
  #expect(result.count == 1)
  #expect(result[0].key == "a.b.c")
  #expect(result[0].value == JSONValue.string("deep"))
}

@Test func flattenArray() {
  let value = JSONValue.array([
    .string("a"),
    .number(.integer(2)),
    .boolean(true),
  ])
  let result = value.flatten()
  #expect(result.count == 3)
  #expect(result[0].key == "[0]")
  #expect(result[0].value == JSONValue.string("a"))
  #expect(result[1].key == "[1]")
  #expect(result[1].value == JSONValue.number(.integer(2)))
  #expect(result[2].key == "[2]")
  #expect(result[2].value == JSONValue.boolean(true))
}

@Test func flattenMixedNested() {
  let value = JSONValue.object([
    "a": .array([
      .number(.integer(1)),
      .object([
        "b": .string("nested")
      ]),
    ])
  ])
  let result = value.flatten()
  #expect(result.count == 2)
  #expect(result[0].key == "a[0]")
  #expect(result[0].value == JSONValue.number(.integer(1)))
  #expect(result[1].key == "a[1].b")
  #expect(result[1].value == JSONValue.string("nested"))
}

@Test func flattenNestedArrayInArray() {
  let value = JSONValue.array([
    .array([
      .string("x"),
      .string("y"),
    ]),
    .string("z"),
  ])
  let result = value.flatten()
  #expect(result.count == 3)
  #expect(result[0].key == "[0][0]")
  #expect(result[0].value == JSONValue.string("x"))
  #expect(result[1].key == "[0][1]")
  #expect(result[1].value == JSONValue.string("y"))
  #expect(result[2].key == "[1]")
  #expect(result[2].value == JSONValue.string("z"))
}

// MARK: - Codable tests

@Test func codableRoundTripPreservesKeyOrder() throws {
  let original = JSONValue.object([
    "z": .number(.integer(1)),
    "a": .number(.integer(2)),
    "m": .number(.integer(3)),
  ])

  let encoder = JSONEncoder()
  let data = try encoder.encode(original)
  let decoder = JSONDecoder()
  let decoded = try decoder.decode(JSONValue.self, from: data)

  guard case .object(let dict) = decoded else {
    Issue.record("Expected object")
    return
  }
  let keys = Array(dict.keys)
  #expect(keys == ["z", "a", "m"])
}

@Test func codableRoundTripPreservesNumericType() throws {
  let jsonString = """
    {
        "int": 42,
        "float": 3.14
    }
    """
  let data = try #require(jsonString.data(using: .utf8))
  let decoder = JSONDecoder()
  let value = try decoder.decode(JSONValue.self, from: data)

  guard case .object(let dict) = value else {
    Issue.record("Expected object")
    return
  }

  let intVal = try #require(dict["int"])
  guard case .number(let intNum) = intVal else {
    Issue.record("Expected number for int")
    return
  }
  #expect(intNum == .integer(42))

  let floatVal = try #require(dict["float"])
  guard case .number(let floatNum) = floatVal else {
    Issue.record("Expected number for float")
    return
  }
  #expect(floatNum == .float(3.14))
}

@Test func codableRoundTripArray() throws {
  let original = JSONValue.array([
    .string("a"),
    .number(.integer(1)),
    .boolean(false),
    .null,
  ])
  let encoder = JSONEncoder()
  let data = try encoder.encode(original)
  let decoder = JSONDecoder()
  let decoded = try decoder.decode(JSONValue.self, from: data)

  guard case .array(let array) = decoded else {
    Issue.record("Expected array")
    return
  }
  #expect(array.count == 4)
  #expect(array[0] == JSONValue.string("a"))
  #expect(array[1] == JSONValue.number(.integer(1)))
  #expect(array[2] == JSONValue.boolean(false))
  #expect(array[3] == JSONValue.null)
}

@Test func codableRoundTripNull() throws {
  let encoder = JSONEncoder()
  let data = try encoder.encode(JSONValue.null)
  let decoder = JSONDecoder()
  let decoded = try decoder.decode(JSONValue.self, from: data)
  #expect(decoded == JSONValue.null)
}

@Test func codableRoundTripString() throws {
  let encoder = JSONEncoder()
  let data = try encoder.encode(JSONValue.string("hello"))
  let decoder = JSONDecoder()
  let decoded = try decoder.decode(JSONValue.self, from: data)
  #expect(decoded == JSONValue.string("hello"))
}

@Test func codableRoundTripNumber() throws {
  let encoder = JSONEncoder()
  let data = try encoder.encode(JSONValue.number(.integer(42)))
  let decoder = JSONDecoder()
  let decoded = try decoder.decode(JSONValue.self, from: data)
  #expect(decoded == JSONValue.number(.integer(42)))
}

@Test func codableRoundTripBoolean() throws {
  let encoder = JSONEncoder()
  let data = try encoder.encode(JSONValue.boolean(true))
  let decoder = JSONDecoder()
  let decoded = try decoder.decode(JSONValue.self, from: data)
  #expect(decoded == JSONValue.boolean(true))
}

// MARK: - Hashable tests

@Test func hashableEquality() {
  #expect(JSONValue.string("a") == JSONValue.string("a"))
  #expect(JSONValue.string("a") != JSONValue.string("b"))
  #expect(JSONValue.number(.integer(1)) == JSONValue.number(.integer(1)))
  #expect(JSONValue.number(.integer(1)) != JSONValue.number(.float(1.0)))
  #expect(JSONValue.boolean(true) == JSONValue.boolean(true))
  #expect(JSONValue.boolean(true) != JSONValue.boolean(false))
  #expect(JSONValue.null == JSONValue.null)
  #expect(JSONValue.string("a") != JSONValue.null)
}
