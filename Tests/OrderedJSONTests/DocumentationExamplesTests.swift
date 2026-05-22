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

// MARK: - Encoding & Decoding (README)

@Test func docEncodingDecoding() throws {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  // Encode a value
  let original = JSONValue.object([
    "z": .number(.integer(1)),
    "a": .number(.integer(2)),
    "m": .number(.integer(3)),
  ])
  let data = try encoder.encode(original)

  // Decode back — key order is preserved
  let decoded = try decoder.decode(JSONValue.self, from: data)
  guard case .object(let dict) = decoded else {
    Issue.record("Expected object")
    return
  }
  // dict.keys == ["z", "a", "m"]
  #expect(Array(dict.keys) == ["z", "a", "m"])
}

@Test func docNumericTypePreservation() throws {
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
  // dict["int"]   == .number(.integer(42))
  // dict["float"] == .number(.float(3.14))
  let intVal = try #require(dict["int"])
  #expect(intVal == .number(.integer(42)))
  let floatVal = try #require(dict["float"])
  #expect(floatVal == .number(.float(3.14)))
}

@Test func docEncodingScalars() throws {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  // Null
  let nullData = try encoder.encode(JSONValue.null)
  let decodedNull = try decoder.decode(JSONValue.self, from: nullData)
  #expect(decodedNull == JSONValue.null)

  // String
  let stringData = try encoder.encode(JSONValue.string("hello"))
  let decodedString = try decoder.decode(JSONValue.self, from: stringData)
  #expect(decodedString == JSONValue.string("hello"))

  // Number
  let numberData = try encoder.encode(JSONValue.number(.integer(42)))
  let decodedNumber = try decoder.decode(JSONValue.self, from: numberData)
  #expect(decodedNumber == JSONValue.number(.integer(42)))

  // Boolean
  let boolData = try encoder.encode(JSONValue.boolean(true))
  let decodedBool = try decoder.decode(JSONValue.self, from: boolData)
  #expect(decodedBool == JSONValue.boolean(true))
}

// MARK: - Key Order Preservation (README)

@Test func docKeyOrderPreservation() throws {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  // Keys are inserted in a specific order
  let original = JSONValue.object([
    "z": .number(.integer(1)),
    "a": .number(.integer(2)),
    "m": .number(.integer(3)),
  ])

  let data = try encoder.encode(original)
  let decoded = try decoder.decode(JSONValue.self, from: data)

  guard case .object(let dict) = decoded else {
    Issue.record("Expected object")
    return
  }
  let keys = Array(dict.keys)
  // keys == ["z", "a", "m"]  — order is preserved
  #expect(keys == ["z", "a", "m"])
}
