import Foundation
import Testing

@testable import OrderedJSON

// MARK: - JSON Codable conformance

@Test func codableEncodeJSONObject() throws {
  let json = JSON.object([
    "name": .string("Alice"),
    "age": .number(.integer(30)),
  ])
  let data = try JSONEncoder().encode(json)
  let decoded = try JSONDecoder().decode(JSON.self, from: data)
  // Foundation's JSONDecoder sorts keys alphabetically, so order may differ
  #expect(decoded["name"] == .string("Alice"))
  #expect(decoded["age"] == .number(.integer(30)))
}

@Test func codableEncodeJSONArray() throws {
  let json = JSON.array([.string("a"), .number(.integer(1)), .boolean(true), .null])
  let data = try JSONEncoder().encode(json)
  let decoded = try JSONDecoder().decode(JSON.self, from: data)
  #expect(decoded.isArray)
  #expect(decoded.count == 4)
  #expect(decoded[0] == .string("a"))
  #expect(decoded[1] == .number(.integer(1)))
  #expect(decoded[2] == .boolean(true))
  #expect(decoded[3] == .null)
}

@Test func codableEncodeJSONScalar() throws {
  let json = JSON.string("hello")
  let data = try JSONEncoder().encode(json)
  let decoded = try JSONDecoder().decode(JSON.self, from: data)
  #expect(decoded == .string("hello"))
}

@Test func codableEncodeJSONNull() throws {
  let json = JSON.null
  let data = try JSONEncoder().encode(json)
  let decoded = try JSONDecoder().decode(JSON.self, from: data)
  #expect(decoded == .null)
}

@Test func codableEncodeJSONNumber() throws {
  let intJson = JSON.number(.integer(42))
  let intData = try JSONEncoder().encode(intJson)
  let intDecoded = try JSONDecoder().decode(JSON.self, from: intData)
  #expect(intDecoded.isInteger)

  let floatJson = JSON.number(.float(3.14))
  let floatData = try JSONEncoder().encode(floatJson)
  let floatDecoded = try JSONDecoder().decode(JSON.self, from: floatData)
  #expect(floatDecoded.isFloat)
}

// MARK: - OrderedJSONEncoder

@Test func orderedEncoderSimpleStruct() throws {
  struct Person: Encodable {
    let name: String
    let age: Int
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Person(name: "Alice", age: 30))
  #expect(json.isObject)
  #expect(json["name"] == .string("Alice"))
  #expect(json["age"] == .number(.integer(30)))
}

@Test func orderedEncoderPreservesKeyOrder() throws {
  struct Ordered: Encodable {
    let z: Int
    let a: Int
    let m: Int
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Ordered(z: 1, a: 2, m: 3))
  #expect(json.isObject)
  #expect(json.count == 3)
  // Keys should be in declaration order: z, a, m
  let keys = json.keys
  #expect(keys?[0] == "z")
  #expect(keys?[1] == "a")
  #expect(keys?[2] == "m")
}

@Test func orderedEncoderNested() throws {
  struct Address: Encodable {
    let city: String
    let zip: String
  }
  struct Person: Encodable {
    let name: String
    let address: Address
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(
    Person(
      name: "Alice",
      address: Address(city: "NYC", zip: "10001")))
  #expect(json["name"] == .string("Alice"))
  #expect(json["address"]?.isObject == true)
  #expect(json["address"]?["city"] == .string("NYC"))
  #expect(json["address"]?["zip"] == .string("10001"))
}

@Test func orderedEncoderArray() throws {
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(["a", "b", "c"])
  #expect(json.isArray)
  #expect(json.count == 3)
  #expect(json[0] == .string("a"))
}

@Test func orderedEncoderToString() throws {
  struct Item: Encodable {
    let id: Int
    let value: String
  }
  let encoder = OrderedJSONEncoder()
  let str = try encoder.encodeToString(Item(id: 1, value: "test"))
  #expect(str == #"{"id":1,"value":"test"}"#)
}

// MARK: - OrderedJSONDecoder

@Test func orderedDecoderFromJSON() throws {
  let json = JSON.object([
    "name": .string("Alice"),
    "age": .number(.integer(30)),
  ])
  let decoder = OrderedJSONDecoder()
  let decoded: JSON = try decoder.decode(JSON.self, from: json)
  #expect(decoded == json)
}

@Test func orderedDecoderFromData() throws {
  let jsonString = #"{"name": "Bob", "age": 25}"#
  let data = Data(jsonString.utf8)
  let decoder = OrderedJSONDecoder()
  let decoded: JSON = try decoder.decode(JSON.self, from: data)
  #expect(decoded["name"] == .string("Bob"))
  #expect(decoded["age"] == .number(.integer(25)))
}

@Test func orderedDecoderFromString() throws {
  let decoder = OrderedJSONDecoder()
  let decoded: JSON = try decoder.decode(JSON.self, from: #"{"x": 1}"#)
  #expect(decoded["x"] == .number(.integer(1)))
}

@Test func orderedDecoderPreservesKeyOrder() throws {
  let jsonString = #"{"z": 1, "a": 2, "m": 3}"#
  let decoder = OrderedJSONDecoder()
  let decoded: JSON = try decoder.decode(JSON.self, from: jsonString)
  let keys = decoded.keys
  #expect(keys?[0] == "z")
  #expect(keys?[1] == "a")
  #expect(keys?[2] == "m")
}

@Test func orderedDecoderStruct() throws {
  struct Person: Decodable {
    let name: String
    let age: Int
  }
  let jsonString = #"{"name": "Alice", "age": 30}"#
  let decoder = OrderedJSONDecoder()
  let person = try decoder.decode(Person.self, from: jsonString)
  #expect(person.name == "Alice")
  #expect(person.age == 30)
}

// MARK: - JSONWithExtras

@Test func jsonWithExtrasDecode() throws {
  struct Person: Decodable {
    let name: String
    let age: Int
  }
  let jsonString = #"""
    {"name": "Alice", "age": 30, "color": "blue", "city": "NYC"}
    """#
  let decoder = OrderedJSONDecoder()
  let wrapped = try decoder.decode(JSONWithExtras<Person>.self, from: jsonString)
  #expect(wrapped.value.name == "Alice")
  #expect(wrapped.value.age == 30)
  #expect(wrapped.extras["color"] == .string("blue"))
  #expect(wrapped.extras["city"] == .string("NYC"))
}

@Test func jsonWithExtrasEncode() throws {
  struct Person: Codable {
    let name: String
    let age: Int
  }
  let extras = JSON.object([
    "color": .string("blue"),
    "city": .string("NYC"),
  ])
  let wrapped = JSONWithExtras(
    value: Person(name: "Alice", age: 30),
    extras: extras)
  let encoder = JSONEncoder()
  let data = try encoder.encode(wrapped)
  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(JSONWithExtras<Person>.self, from: data)
  #expect(back.value.name == "Alice")
  #expect(back.value.age == 30)
}

@Test func jsonWithExtrasNoExtras() throws {
  struct Person: Decodable {
    let name: String
    let age: Int
  }
  let jsonString = #"{"name": "Alice", "age": 30}"#
  let decoder = OrderedJSONDecoder()
  let wrapped = try decoder.decode(JSONWithExtras<Person>.self, from: jsonString)
  #expect(wrapped.value.name == "Alice")
  #expect(wrapped.value.age == 30)
  #expect(wrapped.extras.isEmpty)
}

// MARK: - Throwing accessors

@Test func requireStringSuccess() throws {
  let json = JSON.string("hello")
  #expect(try json.requireString() == "hello")
}

@Test func requireStringThrows() {
  let json = JSON.number(.integer(42))
  #expect {
    try json.requireString()
  } throws: { error in
    guard let jsonError = error as? JSONError else { return false }
    return jsonError == JSONError.typeError(expected: "string", actual: "number")
  }
}

@Test func requireBoolSuccess() throws {
  let json = JSON.boolean(true)
  #expect(try json.requireBool() == true)
}

@Test func requireInt64Success() throws {
  let json = JSON.number(.integer(42))
  #expect(try json.requireInt64() == 42)
}

@Test func requireDoubleSuccess() throws {
  let json = JSON.number(.float(3.14))
  #expect(try json.requireDouble() == 3.14)
}

// MARK: - Helper: JSON keys

extension JSON {
  /// Returns the keys of an object in insertion order, or nil if not an object.
  fileprivate var keys: [String]? {
    guard case .object(let dict) = storage else { return nil }
    return Array(dict.keys)
  }
}

// MARK: - Convenience decode

@Test func convenienceDecodeFromString() throws {
  struct Person: Decodable {
    let name: String
    let age: Int
  }
  let person = try JSON.decode(Person.self, from: "{\"name\": \"Alice\", \"age\": 30}")
  #expect(person.name == "Alice")
  #expect(person.age == 30)
}

@Test func convenienceDecodeFromData() throws {
  struct Person: Decodable {
    let name: String
    let age: Int
  }
  let data = Data("{\"name\": \"Bob\", \"age\": 25}".utf8)
  let person = try JSON.decode(Person.self, from: data)
  #expect(person.name == "Bob")
  #expect(person.age == 25)
}

@Test func convenienceDecodeJSON() throws {
  let json: JSON = try JSON.decode(JSON.self, from: "{\"x\": 1, \"y\": 2}")
  #expect(json["x"] == .number(.integer(1)))
  #expect(json["y"] == .number(.integer(2)))
}

// MARK: - Number normalization

@Test func numberNormalizationCleanDouble() throws {
  let data = Data("42.0".utf8)
  let decoded = try JSONDecoder().decode(JSON.self, from: data)
  #expect(decoded.isInteger)
  #expect(decoded == .number(.integer(42)))
}

@Test func numberNormalizationFractionalDouble() throws {
  let data = Data("3.14".utf8)
  let decoded = try JSONDecoder().decode(JSON.self, from: data)
  #expect(decoded.isFloat)
}

@Test func numberNormalizationLargeInteger() throws {
  let data = Data("1.0e20".utf8)
  let decoded = try JSONDecoder().decode(JSON.self, from: data)
  #expect(decoded.isFloat)
}
