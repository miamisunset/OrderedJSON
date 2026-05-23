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

private struct UserWithExtra: Sendable {
  let name: String
  let email: String
  let extra: OrderedJSONObject

  init(name: String, email: String, extra: OrderedJSONObject) {
    self.name = name
    self.email = email
    self.extra = extra
  }

  init(from jsonData: Data) throws {
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw JSONError.invalidString
    }
    let fullValue = try JSONValue.parse(jsonString)
    guard case .object(let dict) = fullValue else {
      throw JSONError.expectedObject
    }
    let knownKeys: Set<String> = ["name", "email"]
    let (known, extra) = splitExtraFields(from: dict, knownKeys: knownKeys)
    let knownData = try JSONValue.object(known).encodeStandard()
    let base = try JSONDecoder().decode(UserBase.self, from: knownData)
    name = base.name
    email = base.email
    self.extra = extra
  }

  func encode() throws -> Data {
    var known: OrderedJSONObject = [
      "name": .string(name),
      "email": .string(email),
    ]
    for (key, value) in extra {
      known[key] = value
    }
    return try JSONValue.object(known).encodeStandard()
  }
}

private struct UserBase: Decodable, Sendable {
  let name: String
  let email: String
}

@Test func extraFieldsDecodeKnownAndExtra() throws {
  let json = """
    {"name": "Alice", "email": "a@b.com", "age": 30, "city": "NYC"}
    """
  let data = try #require(json.data(using: .utf8))
  let user = try UserWithExtra(from: data)

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
  let user = try UserWithExtra(from: data)

  let encoded = try user.encode()
  let decoded = try UserWithExtra(from: encoded)

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
  let user = try UserWithExtra(from: data)

  #expect(user.name == "Charlie")
  #expect(user.email == "c@d.com")
  #expect(user.extra.isEmpty)
}

@Test func extraFieldsRoundTripEmptyExtra() throws {
  let user = UserWithExtra(
    name: "Dave", email: "d@e.com", extra: [:]
  )
  let data = try user.encode()
  let decoded = try UserWithExtra(from: data)

  #expect(decoded.name == "Dave")
  #expect(decoded.email == "d@e.com")
  #expect(decoded.extra.isEmpty)
}

@Test func extraFieldsRoundTripWithExtra() throws {
  let original = UserWithExtra(
    name: "Eve", email: "e@f.com",
    extra: ["role": .string("admin"), "active": .boolean(true)]
  )
  let data = try original.encode()
  let decoded = try UserWithExtra(from: data)

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
  let user = try UserWithExtra(from: data)

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
