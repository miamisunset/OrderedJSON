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

// MARK: - Extra Fields / Flatten Capture Tests

private struct UserBase: Codable, Sendable {
  let name: String
  let email: String
}

private struct UserWithExtra: Codable, Sendable {
  let name: String
  let email: String
  let extra: OrderedJSONObject

  enum CodingKeys: String, CodingKey, CaseIterable {
    case name, email
  }

  init(name: String, email: String, extra: OrderedJSONObject) {
    self.name = name
    self.email = email
    self.extra = extra
  }

  init(from decoder: any Decoder) throws {
    let fullValue: JSONValue
    // If the decoder has raw data in user info, use order-preserving parsing.
    if let data = decoder.userInfo[.jsonData] as? Data,
      let jsonString = String(data: data, encoding: .utf8)
    {
      fullValue = try JSONValue.parse(jsonString)
    } else {
      fullValue = try JSONValue(from: decoder)
    }
    guard case .object(let dict) = fullValue else {
      throw DecodingError.typeMismatch(
        UserWithExtra.self,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Expected a JSON object"
        )
      )
    }
    let knownKeyStrings = Set(CodingKeys.allCases.map { $0.stringValue })
    let (known, extra) = splitExtraFields(from: dict, knownKeys: knownKeyStrings)
    let knownData = try JSONValue.object(known).encodeStandard()
    let base = try JSONDecoder().decode(UserBase.self, from: knownData)
    name = base.name
    email = base.email
    self.extra = extra
  }

  func encode(to encoder: any Encoder) throws {
    var unkeyed = encoder.unkeyedContainer()
    // Encode known fields as nested pairs
    var namePair = unkeyed.nestedUnkeyedContainer()
    try namePair.encode(CodingKeys.name.stringValue)
    try namePair.encode(name)
    var emailPair = unkeyed.nestedUnkeyedContainer()
    try emailPair.encode(CodingKeys.email.stringValue)
    try emailPair.encode(email)
    for (key, value) in extra {
      var pair = unkeyed.nestedUnkeyedContainer()
      try pair.encode(key)
      try pair.encode(value)
    }
  }
}

@Test func extraFieldsDecodeKnownAndExtra() throws {
  let json = """
    {"name": "Alice", "email": "a@b.com", "age": 30, "city": "NYC"}
    """
  let data = try #require(json.data(using: .utf8))
  let decoder = JSONDecoder()
  decoder.userInfo[.jsonData] = data
  let user = try decoder.decode(UserWithExtra.self, from: data)

  #expect(user.name == "Alice")
  #expect(user.email == "a@b.com")
  #expect(user.extra.keys == ["age", "city"])
  #expect(user.extra["age"] == JSONValue.number(.integer(30)))
  #expect(user.extra["city"] == JSONValue.string("NYC"))
}

@Test func extraFieldsRoundTripPreservesExtraOrder() throws {
  let json = """
    {"z": 1, "name": "Bob", "email": "b@c.com", "a": 2, "age": 30}
    """
  let data = try #require(json.data(using: .utf8))
  let decoder = JSONDecoder()
  decoder.userInfo[.jsonData] = data
  let user = try decoder.decode(UserWithExtra.self, from: data)

  let encoder = JSONEncoder()
  let encoded = try encoder.encode(user)
  // For the round-trip decode, data is from our encoder (nested pairs), not standard JSON.
  let decoded = try decoder.decode(UserWithExtra.self, from: encoded)

  #expect(decoded.name == "Bob")
  #expect(decoded.email == "b@c.com")
  // Extra keys should preserve order through round-trip
  #expect(decoded.extra.keys == ["z", "a", "age"])
  #expect(decoded.extra["z"] == JSONValue.number(.integer(1)))
  #expect(decoded.extra["a"] == JSONValue.number(.integer(2)))
  #expect(decoded.extra["age"] == JSONValue.number(.integer(30)))
}

@Test func extraFieldsEmptyExtra() throws {
  let json = """
    {"name": "Charlie", "email": "c@d.com"}
    """
  let data = try #require(json.data(using: .utf8))
  let decoder = JSONDecoder()
  let user = try decoder.decode(UserWithExtra.self, from: data)

  #expect(user.name == "Charlie")
  #expect(user.email == "c@d.com")
  #expect(user.extra.isEmpty)
}

@Test func extraFieldsRoundTripEmptyExtra() throws {
  let user = UserWithExtra(
    name: "Dave", email: "d@e.com", extra: [:]
  )
  let encoder = JSONEncoder()
  let data = try encoder.encode(user)
  // DBG: encoded = \(String(data: data, encoding: .utf8)!)
  let decoder = JSONDecoder()
  let decoded = try decoder.decode(UserWithExtra.self, from: data)

  #expect(decoded.name == "Dave")
  #expect(decoded.email == "d@e.com")
  #expect(decoded.extra.isEmpty)
}

@Test func extraFieldsDecodeStandardJSONFromJSONEncoder() throws {
  // JSONEncoder produces alternating pairs for objects.
  // Our extra-fields struct should still decode them.
  let original = UserWithExtra(
    name: "Eve", email: "e@f.com",
    extra: ["role": .string("admin"), "active": .boolean(true)]
  )
  let encoder = JSONEncoder()
  let data = try encoder.encode(original)
  let decoder = JSONDecoder()
  let decoded = try decoder.decode(UserWithExtra.self, from: data)

  #expect(decoded.name == "Eve")
  #expect(decoded.email == "e@f.com")
  #expect(decoded.extra.keys == ["role", "active"])
  #expect(decoded.extra["role"] == JSONValue.string("admin"))
  #expect(decoded.extra["active"] == JSONValue.boolean(true))
}

@Test func extraFieldsNestedValues() throws {
  let json = """
    {"name": "Frank", "email": "f@g.com", "meta": {"level": 5, "code": "X"}, "tags": ["a", "b"]}
    """
  let data = try #require(json.data(using: .utf8))
  let decoder = JSONDecoder()
  decoder.userInfo[.jsonData] = data
  let user = try decoder.decode(UserWithExtra.self, from: data)

  #expect(user.name == "Frank")
  #expect(user.email == "f@g.com")
  #expect(user.extra.keys == ["meta", "tags"])
  guard case .object(let meta) = user.extra["meta"]! else {
    Issue.record("Expected nested object")
    return
  }
  #expect(meta["level"] == JSONValue.number(.integer(5)))
  #expect(meta["code"] == JSONValue.string("X"))
  guard case .array(let tags) = user.extra["tags"]! else {
    Issue.record("Expected array")
    return
  }
  #expect(tags == [JSONValue.string("a"), JSONValue.string("b")])
}

// MARK: - JSONValue Standard Encoding Tests

@Test func encodeStandardNull() throws {
  let data = try JSONValue.null.encodeStandard()
  let json = String(data: data, encoding: .utf8)
  #expect(json == "null")
}

@Test func encodeStandardBool() throws {
  let data = try JSONValue.boolean(true).encodeStandard()
  let json = String(data: data, encoding: .utf8)
  #expect(json == "true")
}

@Test func encodeStandardInt() throws {
  let data = try JSONValue.number(.integer(42)).encodeStandard()
  let json = String(data: data, encoding: .utf8)
  #expect(json == "42")
}

@Test func encodeStandardFloat() throws {
  let data = try JSONValue.number(.float(3.14)).encodeStandard()
  let json = String(data: data, encoding: .utf8)
  #expect(json == "3.14")
}

@Test func encodeStandardString() throws {
  let data = try JSONValue.string("hello").encodeStandard()
  let json = String(data: data, encoding: .utf8)
  #expect(json == "\"hello\"")
}

@Test func encodeStandardArray() throws {
  let value = JSONValue.array([
    .string("a"),
    .number(.integer(1)),
    .boolean(true),
  ])
  let data = try value.encodeStandard()
  let json = String(data: data, encoding: .utf8)
  #expect(json == "[\"a\",1,true]")
}

@Test func encodeStandardObject() throws {
  let value = JSONValue.object([
    "name": .string("Alice"),
    "age": .number(.integer(30)),
  ])
  let data = try value.encodeStandard()
  let json = String(data: data, encoding: .utf8)
  #expect(json == "{\"name\":\"Alice\",\"age\":30}")
}

// MARK: - JSONValue.decode(as:) Tests

@Test func decodeAsString() throws {
  let value = JSONValue.string("hello")
  let decoded = try value.decode(as: String.self)
  #expect(decoded == "hello")
}

@Test func decodeAsInt() throws {
  let value = JSONValue.number(.integer(42))
  let decoded = try value.decode(as: Int64.self)
  #expect(decoded == 42)
}

@Test func decodeAsBool() throws {
  let value = JSONValue.boolean(true)
  let decoded = try value.decode(as: Bool.self)
  #expect(decoded == true)
}

@Test func decodeAsDouble() throws {
  let value = JSONValue.number(.float(3.14))
  let decoded = try value.decode(as: Double.self)
  #expect(decoded == 3.14)
}

// MARK: - splitExtraFields Tests

@Test func splitExtraFieldsAllKnown() {
  let dict: OrderedJSONObject = [
    "a": .string("x"),
    "b": .number(.integer(1)),
  ]
  let (known, extra) = splitExtraFields(from: dict, knownKeys: ["a", "b"])
  #expect(known == dict)
  #expect(extra.isEmpty)
}

@Test func splitExtraFieldsAllExtra() {
  let dict: OrderedJSONObject = [
    "x": .string("y"),
    "z": .number(.integer(2)),
  ]
  let (known, extra) = splitExtraFields(from: dict, knownKeys: ["a"])
  #expect(known.isEmpty)
  #expect(extra == dict)
}

@Test func splitExtraFieldsMixed() {
  let dict: OrderedJSONObject = [
    "a": .string("x"),
    "b": .number(.integer(1)),
    "c": .boolean(true),
  ]
  let (known, extra) = splitExtraFields(from: dict, knownKeys: ["a", "c"])
  #expect(known == ["a": .string("x"), "c": .boolean(true)])
  #expect(extra == ["b": .number(.integer(1))])
}

@Test func splitExtraFieldsPreservesOrder() {
  let dict: OrderedJSONObject = [
    "z": .string("first"),
    "a": .string("second"),
    "m": .string("third"),
  ]
  let (_, extra) = splitExtraFields(from: dict, knownKeys: ["a"])
  #expect(extra.keys == ["z", "m"])
}

@Test func splitExtraFieldsEmptyDict() {
  let (known, extra) = splitExtraFields(from: [:], knownKeys: ["a"])
  #expect(known.isEmpty)
  #expect(extra.isEmpty)
}
