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

@Test func jsonWithExtrasContainsMarksAccessed() throws {
  // Regression: contains(_:) should mark the key as accessed
  // so that decodeIfPresent probes don't leak keys into extras
  struct TestStruct: Decodable {
    let x: String
    let y: String?
    enum CodingKeys: String, CodingKey {
      case x, y
    }
    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      x = try container.decode(String.self, forKey: .x)
      y = try container.decodeIfPresent(String.self, forKey: .y)
    }
  }
  let json = JSON.object(["x": .string("hello"), "y": .string("world"), "z": .string("extra")])
  let decoder = OrderedJSONDecoder()
  let decoded = try decoder.decode(JSONWithExtras<TestStruct>.self, from: json)
  #expect(decoded.value.x == "hello")
  #expect(decoded.value.y == "world")
  // 'z' was never accessed via contains or decode, so it appears in extras
  #expect(decoded.extras["z"] == .string("extra"))
}

@Test func jsonWithExtrasDateStrategyPropagated() throws {
  // Regression: date/data/decimal strategies must propagate to the tracking decoder
  struct Person: Decodable {
    let name: String
    let birth: Date
  }
  let json = JSON.object([
    "name": .string("Alice"),
    "birth": .number(.float(1234567890.0)),  // seconds since 1970
    "extra": .string("extra_key"),
  ])
  var decoder = OrderedJSONDecoder()
  decoder.dateDecodingStrategy = .secondsSince1970
  let decoded = try decoder.decode(JSONWithExtras<Person>.self, from: json)
  #expect(decoded.value.name == "Alice")
  #expect(decoded.value.birth.timeIntervalSince1970 == 1234567890.0)
  #expect(decoded.extras["extra"] == .string("extra_key"))
}

@Test func jsonWithExtrasDataStrategyPropagated() throws {
  // Regression: data decoding strategy must propagate to the tracking decoder
  struct Container: Decodable {
    let data: Data
  }
  let json = JSON.object([
    "data": .string("SGVsbG8="),  // base64-encoded "Hello"
    "extra": .number(.integer(42)),
  ])
  var decoder = OrderedJSONDecoder()
  decoder.dataDecodingStrategy = .base64
  let decoded = try decoder.decode(JSONWithExtras<Container>.self, from: json)
  #expect(decoded.value.data == Data([72, 101, 108, 108, 111]))  // "Hello" bytes
  #expect(decoded.extras["extra"] == .number(.integer(42)))
}

@Test func jsonWithExtrasDecimalStrategyPropagated() throws {
  // Regression: decimal decoding strategy must propagate to the tracking decoder
  struct Container: Decodable {
    let amount: Decimal
  }
  let json = JSON.object([
    "amount": .number(.float(3.14)),
    "extra": .string("extra_key"),
  ])
  var decoder = OrderedJSONDecoder()
  decoder.decimalDecodingStrategy = .asNumber
  let decoded = try decoder.decode(JSONWithExtras<Container>.self, from: json)
  #expect(decoded.value.amount == Decimal(string: "3.14"))
  #expect(decoded.extras["extra"] == .string("extra_key"))
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

// MARK: - Integer and unsigned width accessors

@Test func requireInt8Success() throws {
  let json = JSON.number(.integer(42))
  #expect(try json.requireInt8() == 42)
}

@Test func requireInt8Overflow() throws {
  let json = JSON.number(.integer(200))
  #expect {
    try json.requireInt8()
  } throws: { error in
    guard let jsonError = error as? JSONError else { return false }
    return jsonError == JSONError.typeError(expected: "int8", actual: "number")
  }
}

@Test func requireInt16Success() throws {
  let json = JSON.number(.integer(300))
  #expect(try json.requireInt16() == 300)
}

@Test func requireInt32Success() throws {
  let json = JSON.number(.integer(100_000))
  #expect(try json.requireInt32() == 100_000)
}

@Test func requireUIntSuccess() throws {
  let json = JSON.number(.integer(42))
  #expect(try json.requireUInt() == 42)
}

@Test func requireUIntNegativeThrows() throws {
  let json = JSON.number(.integer(-1))
  #expect {
    try json.requireUInt()
  } throws: { error in
    guard let jsonError = error as? JSONError else { return false }
    return jsonError == JSONError.typeError(expected: "uint", actual: "number")
  }
}

@Test func requireUInt8Success() throws {
  let json = JSON.number(.integer(255))
  #expect(try json.requireUInt8() == 255)
}

@Test func requireUInt8Overflow() throws {
  let json = JSON.number(.integer(256))
  #expect {
    try json.requireUInt8()
  } throws: { error in
    guard let jsonError = error as? JSONError else { return false }
    return jsonError == JSONError.typeError(expected: "uint8", actual: "number")
  }
}

@Test func requireUInt16Success() throws {
  let json = JSON.number(.integer(42_000))
  #expect(try json.requireUInt16() == 42_000)
}

@Test func requireUInt32Success() throws {
  let json = JSON.number(.integer(2_000_000_000))
  #expect(try json.requireUInt32() == 2_000_000_000)
}

@Test func requireUInt64Success() throws {
  let json = JSON.number(.integer(42))
  #expect(try json.requireUInt64() == 42)
}

@Test func requireUInt64NegativeThrows() throws {
  let json = JSON.number(.integer(-1))
  #expect {
    try json.requireUInt64()
  } throws: { error in
    guard let jsonError = error as? JSONError else { return false }
    return jsonError == JSONError.typeError(expected: "uint64", actual: "number")
  }
}

// MARK: - requireDouble accepts integers

@Test func requireDoubleFromInteger() throws {
  let json = JSON.number(.integer(42))
  #expect(try json.requireDouble() == 42.0)
}

@Test func requireDoubleFromFloat() throws {
  let json = JSON.number(.float(3.14))
  #expect(try json.requireDouble() == 3.14)
}

@Test func requireDoubleThrowsOnNonNumber() throws {
  let json = JSON.string("hello")
  #expect {
    try json.requireDouble()
  } throws: { error in
    guard let jsonError = error as? JSONError else { return false }
    return jsonError == JSONError.typeError(expected: "float", actual: "string")
  }
}

@Test func requireFloatRejectsLossyDouble() throws {
  // 0.1 is not exactly representable as Float
  let json = JSON.number(.float(0.1))
  #expect {
    try json.requireFloat()
  } throws: { error in
    guard let jsonError = error as? JSONError else { return false }
    return jsonError == JSONError.typeError(expected: "float", actual: "number")
  }
}

@Test func requireFloatFromInteger() throws {
  // Clean integers are exactly representable as Float
  let json = JSON.number(.integer(42))
  #expect(try json.requireFloat() == 42.0)
}

@Test func requireInt64FromFloat() throws {
  // Clean integer stored as .float should still work with requireInt64
  let json = JSON.number(.float(42.0))
  #expect(try json.requireInt64() == 42)
}

// MARK: - Generic get<T>() Tests

@Test func getString() throws {
  let json = JSON.string("hello")
  let value: String = try json.get(String.self)
  #expect(value == "hello")
}

@Test func getBool() throws {
  let json = JSON.boolean(true)
  let value: Bool = try json.get(Bool.self)
  #expect(value == true)
}

@Test func getInt64() throws {
  let json = JSON.number(.integer(42))
  let value: Int64 = try json.get(Int64.self)
  #expect(value == 42)
}

@Test func getInt() throws {
  let json = JSON.number(.integer(42))
  let value: Int = try json.get(Int.self)
  #expect(value == 42)
}

@Test func getDouble() throws {
  let json = JSON.number(.float(3.14))
  let value: Double = try json.get(Double.self)
  #expect(value == 3.14)
}

@Test func getDoubleFromInteger() throws {
  let json = JSON.number(.integer(42))
  let value: Double = try json.get(Double.self)
  #expect(value == 42.0)
}

@Test func getFloat() throws {
  let json = JSON.number(.integer(42))
  let value: Float = try json.get(Float.self)
  #expect(value == 42.0)
}

@Test func getUInt() throws {
  let json = JSON.number(.integer(42))
  let value: UInt = try json.get(UInt.self)
  #expect(value == 42)
}

@Test func getUInt8() throws {
  let json = JSON.number(.integer(42))
  let value: UInt8 = try json.get(UInt8.self)
  #expect(value == 42)
}

@Test func getTypeMismatchThrows() throws {
  let json = JSON.string("hello")
  #expect {
    _ = try json.get(Int64.self)
  } throws: { error in
    guard let jsonError = error as? JSONError else { return false }
    // requireInt64() reports expected "integer", not "Int64"
    return jsonError == JSONError.typeError(expected: "integer", actual: "string")
  }
}

@Test func getUnsupportedTypeFallbackThrows() throws {
  // Exercise the final `throw` in get<T>() — an unsupported T type like Date
  struct MyType: Hashable, Sendable {}
  let json = JSON.string("hello")
  #expect {
    _ = try json.get(MyType.self)
  } throws: { error in
    guard let jsonError = error as? JSONError else { return false }
    // Fallback reports T.self name as the expected type
    return jsonError == JSONError.typeError(expected: "MyType", actual: "string")
  }
}

@Test func getInt8() throws {
  let json = JSON.number(.integer(42))
  let value: Int8 = try json.get(Int8.self)
  #expect(value == 42)
}

@Test func getInt16() throws {
  let json = JSON.number(.integer(42))
  let value: Int16 = try json.get(Int16.self)
  #expect(value == 42)
}

@Test func getInt32() throws {
  let json = JSON.number(.integer(42))
  let value: Int32 = try json.get(Int32.self)
  #expect(value == 42)
}

@Test func getUInt16() throws {
  let json = JSON.number(.integer(42))
  let value: UInt16 = try json.get(UInt16.self)
  #expect(value == 42)
}

@Test func getUInt32() throws {
  let json = JSON.number(.integer(42))
  let value: UInt32 = try json.get(UInt32.self)
  #expect(value == 42)
}

@Test func getUInt64() throws {
  let json = JSON.number(.integer(42))
  let value: UInt64 = try json.get(UInt64.self)
  #expect(value == 42)
}

@Test func getInt8BoundsCheckThrows() throws {
  let json = JSON.number(.integer(300))  // > Int8.max
  #expect {
    _ = try json.get(Int8.self)
  } throws: { error in
    guard let jsonError = error as? JSONError else { return false }
    return jsonError == JSONError.typeError(expected: "int8", actual: "number")
  }
}

@Test func requireInt64FromFloatThrows() throws {
  // Fractional float should throw
  let json = JSON.number(.float(3.14))
  #expect {
    try json.requireInt64()
  } throws: { error in
    guard let jsonError = error as? JSONError else { return false }
    return jsonError == JSONError.typeError(expected: "integer", actual: "number")
  }
}

// MARK: - Integer and unsigned width encoding/decoding

@Test func encodeDecodeInt8() throws {
  struct Value: Codable {
    let x: Int8
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Value(x: 42))
  #expect(json["x"] == .number(.integer(42)))

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Value.self, from: json)
  #expect(back.x == 42)
}

@Test func encodeDecodeInt16() throws {
  struct Value: Codable {
    let x: Int16
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Value(x: 42))
  #expect(json["x"] == .number(.integer(42)))

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Value.self, from: json)
  #expect(back.x == 42)
}

@Test func encodeDecodeInt32() throws {
  struct Value: Codable {
    let x: Int32
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Value(x: 42))
  #expect(json["x"] == .number(.integer(42)))

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Value.self, from: json)
  #expect(back.x == 42)
}

@Test func encodeDecodeUInt() throws {
  struct Value: Codable {
    let x: UInt
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Value(x: 42))
  #expect(json["x"] == .number(.integer(42)))

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Value.self, from: json)
  #expect(back.x == 42)
}

@Test func encodeDecodeUInt8() throws {
  struct Value: Codable {
    let x: UInt8
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Value(x: 255))
  #expect(json["x"] == .number(.integer(255)))

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Value.self, from: json)
  #expect(back.x == 255)
}

@Test func encodeDecodeUInt16() throws {
  struct Value: Codable {
    let x: UInt16
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Value(x: 42_000))
  #expect(json["x"] == .number(.integer(42_000)))

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Value.self, from: json)
  #expect(back.x == 42_000)
}

@Test func encodeDecodeUInt32() throws {
  struct Value: Codable {
    let x: UInt32
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Value(x: 2_000_000_000))
  #expect(json["x"] == .number(.integer(2_000_000_000)))

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Value.self, from: json)
  #expect(back.x == 2_000_000_000)
}

@Test func encodeDecodeUInt64() throws {
  struct Value: Codable {
    let x: UInt64
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Value(x: 42))
  #expect(json["x"] == .number(.integer(42)))

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Value.self, from: json)
  #expect(back.x == 42)
}

@Test func encodeUInt64OverflowThrows() throws {
  struct Value: Encodable {
    let x: UInt64
  }
  let encoder = OrderedJSONEncoder()
  // UInt64.max > Int64.max, so encoding should throw
  #expect {
    try encoder.encode(Value(x: UInt64.max))
  } throws: { error in
    guard let encodingError = error as? EncodingError else { return false }
    switch encodingError {
    case .invalidValue(_, let ctx):
      return ctx.debugDescription.contains("overflows Int64")
    default: return false
    }
  }
}

// MARK: - Optional / decodeIfPresent

@Test func decodeIfPresentPresent() throws {
  struct Person: Decodable {
    let name: String
    let age: Int?
  }
  let json = #"{"name": "Alice", "age": 30}"#
  let decoder = OrderedJSONDecoder()
  let person = try decoder.decode(Person.self, from: json)
  #expect(person.name == "Alice")
  #expect(person.age == 30)
}

@Test func decodeIfPresentMissing() throws {
  struct Person: Decodable {
    let name: String
    let age: Int?
  }
  let json = #"{"name": "Alice"}"#
  let decoder = OrderedJSONDecoder()
  let person = try decoder.decode(Person.self, from: json)
  #expect(person.name == "Alice")
  #expect(person.age == nil)
}

@Test func decodeIfPresentExplicitNull() throws {
  struct Person: Decodable {
    let name: String
    let age: Int?
  }
  let json = #"{"name": "Alice", "age": null}"#
  let decoder = OrderedJSONDecoder()
  let person = try decoder.decode(Person.self, from: json)
  #expect(person.name == "Alice")
  #expect(person.age == nil)
}

@Test func decodeIfPresentMissingWithExtras() throws {
  struct Person: Decodable {
    let name: String
    let age: Int?
  }
  let json = #"{"name": "Alice", "color": "blue"}"#
  let decoder = OrderedJSONDecoder()
  let wrapped = try decoder.decode(JSONWithExtras<Person>.self, from: json)
  #expect(wrapped.value.name == "Alice")
  #expect(wrapped.value.age == nil)
  #expect(wrapped.extras["color"] == .string("blue"))
}

// MARK: - Round-trip via OrderedJSONEncoder → dump → parse → OrderedJSONDecoder

@Test func orderedJSONEncoderDecoderRoundTrip() throws {
  struct Person: Codable {
    let name: String
    let age: Int
  }
  let original = Person(name: "Alice", age: 30)
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(original)
  let jsonString = json.dump(indent: -1)
  let parsed = try JSON.parse(jsonString)
  let decoder = OrderedJSONDecoder()
  let roundTripped = try decoder.decode(Person.self, from: parsed)
  #expect(roundTripped.name == "Alice")
  #expect(roundTripped.age == 30)
}

@Test func orderedJSONEncoderDecoderArrayRoundTrip() throws {
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode([1, 2, 3])
  let jsonString = json.dump(indent: -1)
  let parsed = try JSON.parse(jsonString)
  let decoder = OrderedJSONDecoder()
  let arr = try decoder.decode([Int].self, from: parsed)
  #expect(arr == [1, 2, 3])
}

@Test func orderedJSONEncoderDecoderNestedRoundTrip() throws {
  struct Address: Codable {
    let city: String
    let zip: String
  }
  struct Person: Codable {
    let name: String
    let address: Address
  }
  let original = Person(
    name: "Alice",
    address: Address(city: "NYC", zip: "10001"))
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(original)
  let jsonString = json.dump(indent: -1)
  let parsed = try JSON.parse(jsonString)
  let decoder = OrderedJSONDecoder()
  let roundTripped = try decoder.decode(Person.self, from: parsed)
  #expect(roundTripped.name == "Alice")
  #expect(roundTripped.address.city == "NYC")
  #expect(roundTripped.address.zip == "10001")
}

// MARK: - Nested container via explicit nestedContainer(keyedBy:forKey:)

@Test func explicitNestedContainerEncode() throws {
  struct Inner: Encodable {
    let x: Int
  }
  struct Outer: Encodable {
    let inner: Inner

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      var nested = container.nestedContainer(
        keyedBy: InnerKeys.self, forKey: .inner)
      try nested.encode(inner.x, forKey: .x)
    }

    enum CodingKeys: CodingKey {
      case inner
    }

    enum InnerKeys: CodingKey {
      case x
    }
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Outer(inner: Inner(x: 42)))
  // The inner object should be populated, not empty/null
  #expect(json["inner"]?.isObject == true)
  #expect(json["inner"]?["x"] == .number(.integer(42)))
}

@Test func explicitNestedUnkeyedContainerEncode() throws {
  struct Wrapper: Encodable {
    let items: [Int]

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      var nested = container.nestedUnkeyedContainer(forKey: .items)
      try nested.encode(1)
      try nested.encode(2)
      try nested.encode(3)
    }

    enum CodingKeys: CodingKey {
      case items
    }
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Wrapper(items: []))
  // The array should be populated, not empty
  #expect(json["items"]?.isArray == true)
  #expect(json["items"]?.count == 3)
  #expect(json["items"]?[0] == .number(.integer(1)))
  #expect(json["items"]?[1] == .number(.integer(2)))
  #expect(json["items"]?[2] == .number(.integer(3)))
}

// MARK: - Key order preservation through OrderedJSONDecoder

@Test func orderedDecoderKeyOrderForStruct() throws {
  struct Ordered: Decodable {
    let z: String
    let a: String
    let m: String

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      // Record the order of allKeys
      let keys = container.allKeys.map { $0.stringValue }
      // allKeys should be in insertion order: z, a, m
      #expect(keys == ["z", "a", "m"])
      z = try container.decode(String.self, forKey: .z)
      a = try container.decode(String.self, forKey: .a)
      m = try container.decode(String.self, forKey: .m)
    }

    enum CodingKeys: CodingKey {
      case z, a, m
    }
  }
  let jsonString = #"{"z": "1", "a": "2", "m": "3"}"#
  let decoder = OrderedJSONDecoder()
  let _ = try decoder.decode(Ordered.self, from: jsonString)
}

// MARK: - JSONWithExtras: extras must be object

@Test func jsonWithExtrasNonObjectExtrasThrowsOnEncode() throws {
  struct Person: Codable {
    let name: String
  }
  let wrapped = JSONWithExtras(
    value: Person(name: "Alice"),
    extras: .null)
  let encoder = JSONEncoder()
  #expect {
    try encoder.encode(wrapped)
  } throws: { error in
    guard let encodingError = error as? EncodingError else { return false }
    switch encodingError {
    case .invalidValue(_, let ctx):
      return ctx.debugDescription.contains("Extras must be a JSON object")
    default: return false
    }
  }
}

// MARK: - Coding path propagation

@Test func codingPathIncludesKeys() throws {
  struct Inner: Decodable {
    let x: Int
  }
  struct Outer: Decodable {
    let inner: Inner
  }
  // Missing "x" key in inner should produce path ["inner", "x"]
  let json = #"{"inner": {}}"#
  let decoder = OrderedJSONDecoder()
  #expect {
    try decoder.decode(Outer.self, from: json)
  } throws: { error in
    guard let decodingError = error as? DecodingError else { return false }
    switch decodingError {
    case .keyNotFound(let key, let ctx):
      // key should be "x" and path should include "inner"
      return key.stringValue == "x" && ctx.codingPath.count >= 1
    default: return false
    }
  }
}

// MARK: - Super encoder

@Test func superEncoderWritesUnderSuperKey() throws {
  class Base: Encodable {
    let baseValue: Int = 42
    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(baseValue, forKey: .baseValue)
    }
    enum CodingKeys: CodingKey {
      case baseValue
    }
  }

  class Derived: Base {
    let derivedValue: String = "hello"

    override func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(derivedValue, forKey: .derivedValue)

      // Super encoder for the parent class — writes under "super" key
      let superEncoder = container.superEncoder()
      try super.encode(to: superEncoder)
    }

    enum CodingKeys: CodingKey {
      case derivedValue
    }
  }

  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Derived())
  // The "super" key should contain the base class's encoded value
  #expect(json["derivedValue"] == .string("hello"))
  #expect(json["super"]?.isObject == true)
  #expect(json["super"]?["baseValue"] == .number(.integer(42)))
}

// MARK: - Top-level JSON.encode(_:) and JSON.decode(_:from:) convenience

@Test func topLevelEncodeStruct() throws {
  struct Person: Encodable {
    let name: String
    let age: Int
  }
  let person = Person(name: "Alice", age: 30)
  let json = try JSON.encode(person)
  #expect(json.isObject)
  #expect(json["name"] == .string("Alice"))
  #expect(json["age"] == .number(.integer(30)))
}

@Test func topLevelEncodeArray() throws {
  let json = try JSON.encode([1, 2, 3])
  #expect(json.isArray)
  #expect(json.count == 3)
  #expect(json[0] == .number(.integer(1)))
  #expect(json[1] == .number(.integer(2)))
  #expect(json[2] == .number(.integer(3)))
}

@Test func topLevelEncodeString() throws {
  let json = try JSON.encode("hello")
  #expect(json.isString)
  #expect(json == .string("hello"))
}

@Test func topLevelDecodeFromJSON() throws {
  struct Person: Decodable {
    let name: String
    let age: Int
  }
  let json = JSON.object([
    "name": .string("Bob"),
    "age": .number(.integer(25)),
  ])
  let person = try JSON.decode(Person.self, from: json)
  #expect(person.name == "Bob")
  #expect(person.age == 25)
}

@Test func topLevelDecodeJSONType() throws {
  let json = JSON.object(["x": .number(.integer(1)), "y": .number(.integer(2))])
  let decoded: JSON = try JSON.decode(JSON.self, from: json)
  #expect(decoded["x"] == .number(.integer(1)))
  #expect(decoded["y"] == .number(.integer(2)))
}

@Test func topLevelEncodeDecodeRoundTrip() throws {
  struct Person: Codable {
    let name: String
    let age: Int
  }
  let original = Person(name: "Alice", age: 30)
  let encoded = try JSON.encode(original)
  let decoded = try JSON.decode(Person.self, from: encoded)
  #expect(decoded.name == "Alice")
  #expect(decoded.age == 30)
}

@Test func topLevelEncodePreservesKeyOrder() throws {
  struct Ordered: Encodable {
    let z: Int
    let a: Int
    let m: Int
  }
  let json = try JSON.encode(Ordered(z: 1, a: 2, m: 3))
  #expect(json.isObject)
  #expect(json.count == 3)
  let keys = json.keys
  #expect(keys?[0] == "z")
  #expect(keys?[1] == "a")
  #expect(keys?[2] == "m")
}

// MARK: - Foundation type interop

@Test func foundationDateDefault() throws {
  struct Container: Codable {
    let timestamp: Date
  }
  let date = Date(timeIntervalSince1970: 1_234_567_890)
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Container(timestamp: date))
  // Default strategy (.deferredToDate) uses Date's own encoding (timeIntervalSinceReferenceDate)
  #expect(json.isObject)
  #expect(json["timestamp"]?.isFloat == true)

  // Round-trip
  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.timestamp.timeIntervalSinceReferenceDate == date.timeIntervalSinceReferenceDate)
}

@Test func foundationDateSecondsSince1970() throws {
  struct Container: Codable {
    let timestamp: Date
  }
  let date = Date(timeIntervalSince1970: 1_234_567_890)
  var encoder = OrderedJSONEncoder()
  encoder.dateEncodingStrategy = .secondsSince1970
  let json = try encoder.encode(Container(timestamp: date))
  #expect(json["timestamp"] == .number(.float(1_234_567_890)))

  var decoder = OrderedJSONDecoder()
  decoder.dateDecodingStrategy = .secondsSince1970
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.timestamp.timeIntervalSince1970 == 1_234_567_890)
}

@Test func foundationDateMillisecondsSince1970() throws {
  struct Container: Codable {
    let timestamp: Date
  }
  let date = Date(timeIntervalSince1970: 1_234_567_890)
  var encoder = OrderedJSONEncoder()
  encoder.dateEncodingStrategy = .millisecondsSince1970
  let json = try encoder.encode(Container(timestamp: date))
  #expect(json["timestamp"] == .number(.float(1_234_567_890_000)))

  var decoder = OrderedJSONDecoder()
  decoder.dateDecodingStrategy = .millisecondsSince1970
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.timestamp.timeIntervalSince1970 == 1_234_567_890)
}

@Test func foundationDateISO8601() throws {
  struct Container: Codable {
    let timestamp: Date
  }
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  let date = Date(timeIntervalSince1970: 1_234_567_890)
  let dateString = formatter.string(from: date)

  var encoder = OrderedJSONEncoder()
  encoder.dateEncodingStrategy = .iso8601
  let json = try encoder.encode(Container(timestamp: date))
  #expect(json["timestamp"] == .string(dateString))

  var decoder = OrderedJSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  let back = try decoder.decode(Container.self, from: json)
  #expect(formatter.string(from: back.timestamp) == dateString)
}

@Test func foundationDateFormatted() throws {
  struct Container: Codable {
    let timestamp: Date
  }
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
  let date = Date(timeIntervalSince1970: 1_234_567_890)
  let dateString = formatter.string(from: date)

  var encoder = OrderedJSONEncoder()
  encoder.dateEncodingStrategy = .formatted(formatter)
  let json = try encoder.encode(Container(timestamp: date))
  #expect(json["timestamp"] == .string(dateString))

  var decoder = OrderedJSONDecoder()
  decoder.dateDecodingStrategy = .formatted(formatter)
  let back = try decoder.decode(Container.self, from: json)
  #expect(formatter.string(from: back.timestamp) == dateString)
}

@Test func foundationDataBase64() throws {
  struct Container: Codable {
    let data: Data
  }
  let original = Data([0xDE, 0xAD, 0xBE, 0xEF])
  let b64 = original.base64EncodedString()

  var encoder = OrderedJSONEncoder()
  encoder.dataEncodingStrategy = .base64
  let json = try encoder.encode(Container(data: original))
  #expect(json["data"] == .string(b64))

  var decoder = OrderedJSONDecoder()
  decoder.dataDecodingStrategy = .base64
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.data == original)
}

@Test func foundationURL() throws {
  struct Container: Codable {
    let url: URL
  }
  let url = URL(string: "https://example.com/path")!
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Container(url: url))
  #expect(json["url"] == .string(url.absoluteString))

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.url == url)
}

@Test func foundationUUID() throws {
  struct Container: Codable {
    let id: UUID
  }
  let uuid = UUID()
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Container(id: uuid))
  #expect(json["id"] == .string(uuid.uuidString))

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.id == uuid)
}

@Test func foundationDecimal() throws {
  struct Container: Codable {
    let amount: Decimal
  }
  let decimal = Decimal(string: "3.14159")!
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Container(amount: decimal))
  #expect(json["amount"]?.isString == true)
  #expect(json["amount"]?.stringValue == "3.14159")

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.amount == decimal)
}

@Test func foundationDecimalAsNumber() throws {
  struct Container: Codable {
    let amount: Decimal
  }
  let decimal = Decimal(string: "3.14159")!
  var encoder = OrderedJSONEncoder()
  encoder.decimalEncodingStrategy = .asNumber
  let json = try encoder.encode(Container(amount: decimal))
  #expect(json["amount"]?.isNumber == true)
  var decoder = OrderedJSONDecoder()
  decoder.decimalDecodingStrategy = .asNumber
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.amount == decimal)
}

@Test func foundationDecimalAsNumberHugeThrows() throws {
  // Regression test: Decimal with huge exponent must not cause Int64(Double.infinity) crash
  struct Container: Codable {
    let amount: Decimal
  }
  // A Decimal with exponent that overflows Double to infinity
  let huge = Decimal(string: "1e400")!
  var encoder = OrderedJSONEncoder()
  encoder.decimalEncodingStrategy = .asNumber
  // Should throw EncodingError, not crash
  #expect(throws: EncodingError.self) {
    try encoder.encode(Container(amount: huge))
  }
}

@Test func foundationDateCustomStrategy() throws {
  struct Container: Codable {
    let timestamp: Date
  }
  let date = Date(timeIntervalSince1970: 42)
  var encoder = OrderedJSONEncoder()
  encoder.dateEncodingStrategy = .custom { d, _ in
    return .object(["epoch": .number(.integer(Int64(d.timeIntervalSince1970)))])
  }
  let json = try encoder.encode(Container(timestamp: date))
  #expect(json["timestamp"]?.isObject == true)
  #expect(json["timestamp"]?["epoch"] == .number(.integer(42)))

  var decoder = OrderedJSONDecoder()
  decoder.dateDecodingStrategy = .custom { json, _ in
    return Date(timeIntervalSince1970: try json["epoch"]!.requireDouble())
  }
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.timestamp.timeIntervalSince1970 == 42)
}

@Test func foundationDataCustomStrategy() throws {
  struct Container: Codable {
    let data: Data
  }
  let original = Data([0x01, 0x02])
  var encoder = OrderedJSONEncoder()
  encoder.dataEncodingStrategy = .custom { d, _ in
    return .number(.integer(Int64(d.count)))
  }
  let json = try encoder.encode(Container(data: original))
  #expect(json["data"] == .number(.integer(2)))

  var decoder = OrderedJSONDecoder()
  decoder.dataDecodingStrategy = .custom { json, _ in
    return Data([0x01, 0x02])
  }
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.data == original)
}

// MARK: - Invalid input error handling

@Test func invalidURLStringThrows() throws {
  struct Container: Decodable {
    let url: URL
  }
  let decoder = OrderedJSONDecoder()
  // Empty string should throw dataCorrupted, not crash
  let json = JSON.object(["url": .string("")])
  #expect {
    try decoder.decode(Container.self, from: json)
  } throws: { error in
    guard let decodingError = error as? DecodingError else { return false }
    switch decodingError {
    case .dataCorrupted(let ctx):
      return ctx.debugDescription.contains("Invalid URL")
    default: return false
    }
  }
}

@Test func invalidUUIDStringThrows() throws {
  struct Container: Decodable {
    let id: UUID
  }
  let decoder = OrderedJSONDecoder()
  // Invalid UUID format should throw dataCorrupted, not crash
  let json = JSON.object(["id": .string("not-a-uuid")])
  #expect {
    try decoder.decode(Container.self, from: json)
  } throws: { error in
    guard let decodingError = error as? DecodingError else { return false }
    switch decodingError {
    case .dataCorrupted(let ctx):
      return ctx.debugDescription.contains("Invalid UUID")
    default: return false
    }
  }
}

@Test func invalidDecimalStringThrows() throws {
  struct Container: Decodable {
    let amount: Decimal
  }
  let decoder = OrderedJSONDecoder()
  // Non-numeric string should throw dataCorrupted, not return Decimal.nan
  let json = JSON.object(["amount": .string("not-a-number")])
  #expect {
    try decoder.decode(Container.self, from: json)
  } throws: { error in
    guard let decodingError = error as? DecodingError else { return false }
    switch decodingError {
    case .dataCorrupted(let ctx):
      return ctx.debugDescription.contains("Invalid Decimal")
    default: return false
    }
  }
}

@Test func invalidDecimalAsNumberThrows() throws {
  struct Container: Decodable {
    let amount: Decimal
  }
  var decoder = OrderedJSONDecoder()
  decoder.decimalDecodingStrategy = .asNumber
  // Non-number value should throw typeMismatch, not return Decimal.nan
  let json = JSON.object(["amount": .string("not-a-number")])
  #expect {
    try decoder.decode(Container.self, from: json)
  } throws: { error in
    guard let decodingError = error as? DecodingError else { return false }
    switch decodingError {
    case .typeMismatch:
      return true
    default: return false
    }
  }
}

// MARK: - Optional Date via decodeIfPresent

@Test func foundationOptionalDatePresent() throws {
  struct Container: Decodable {
    let timestamp: Date?
  }
  let decoder = OrderedJSONDecoder()
  let json = JSON.object(["timestamp": .number(.float(0))])
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.timestamp != nil)
}

@Test func foundationOptionalDateMissing() throws {
  struct Container: Decodable {
    let timestamp: Date?
  }
  let decoder = OrderedJSONDecoder()
  let json = JSON.object([:])
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.timestamp == nil)
}

@Test func foundationOptionalDateExplicitNull() throws {
  struct Container: Decodable {
    let timestamp: Date?
  }
  let decoder = OrderedJSONDecoder()
  let json = JSON.object(["timestamp": .null])
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.timestamp == nil)
}

// MARK: - Strategy propagation through custom closures

@Test func strategyPropagationInDeferredDate() throws {
  // When .deferredToDate is used, a child impl is created internally.
  // Verify that the child impl receives the configured strategies.
  struct Outer: Codable {
    let timestamp: Date
    let config: Decimal
  }

  var encoder = OrderedJSONEncoder()
  encoder.dateEncodingStrategy = .deferredToDate
  encoder.decimalEncodingStrategy = .asString
  let date = Date(timeIntervalSince1970: 100)
  let decimal = Decimal(string: "2.71828")!
  let json = try encoder.encode(Outer(timestamp: date, config: decimal))
  // Date should use Date's own encoding (float), Decimal should be string
  #expect(json["timestamp"]?.isFloat == true)
  #expect(json["config"]?.isString == true)
  #expect(json["config"]?.stringValue == "2.71828")

  var decoder = OrderedJSONDecoder()
  decoder.dateDecodingStrategy = .deferredToDate
  decoder.decimalDecodingStrategy = .asString
  let back = try decoder.decode(Outer.self, from: json)
  #expect(back.timestamp.timeIntervalSinceReferenceDate == date.timeIntervalSinceReferenceDate)
  #expect(back.config == decimal)
}

// MARK: - Date in nested unkeyed container

@Test func foundationDateInUnkeyedContainer() throws {
  struct Container: Decodable {
    let dates: [Date]
  }
  var decoder = OrderedJSONDecoder()
  decoder.dateDecodingStrategy = .secondsSince1970
  let json = JSON.object(["dates": .array([.number(.float(1_000)), .number(.float(2_000))])])
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.dates.count == 2)
  #expect(back.dates[0].timeIntervalSince1970 == 1_000)
  #expect(back.dates[1].timeIntervalSince1970 == 2_000)
}

// MARK: - Decodable overflow protection

@Test func decodeDoubleNearInt64Max() throws {
  // Double(Int64.max) rounds up beyond Int64.max — must not crash
  let json = JSON.number(.float(Double(Int64.max)))
  let encoder = JSONEncoder()
  let data = try encoder.encode(json)
  // Round-trip through JSONSerialization to simulate a decoder
  // that produces a double near Int64.max
  let decoder = JSONDecoder()
  let decoded = try decoder.decode(JSON.self, from: data)
  // Double(Int64.max) rounds up to 2^63, which is not representable as Int64
  // Must decode as float, not crash
  #expect(decoded.isFloat)
}

@Test func decodeLargeDoubleStaysFloat() throws {
  // A double value that exceeds Int64.max should remain float
  let value = Double(Int64.max) * 2  // way beyond Int64.max
  let json = JSON.number(.float(value))
  let encoder = JSONEncoder()
  let data = try encoder.encode(json)
  let decoder = JSONDecoder()
  let decoded = try decoder.decode(JSON.self, from: data)
  #expect(decoded.isFloat)
  if case .number(.float(let d)) = decoded.storage {
    #expect(d == value)
  }
}

@Test func decodeNegativeDoubleNearInt64Min() throws {
  // Double(Int64.min) is exactly representable — must not overflow
  let value = Double(Int64.min)
  let json = JSON.number(.float(value))
  let encoder = JSONEncoder()
  let data = try encoder.encode(json)
  let decoder = JSONDecoder()
  let decoded = try decoder.decode(JSON.self, from: data)
  // Should normalize to integer since it's exact
  #expect(decoded.isInteger)
  if case .number(.integer(let i)) = decoded.storage {
    #expect(i == Int64.min)
  }
}

// MARK: - NaN/Infinity via Encodable path

@Test func nanFloatThroughJSONEncoder() throws {
  // JSON.number(.float(NaN)) encodes as null via JSON: Encodable
  let json = JSON.number(.float(Double.nan))
  let encoder = JSONEncoder()
  let data = try encoder.encode(json)
  let string = String(data: data, encoding: .utf8)!
  #expect(string == "null" || string == "[null]")
}

@Test func infinityFloatThroughJSONEncoder() throws {
  // JSON.number(.float(Infinity)) encodes as null via JSON: Encodable
  let json = JSON.number(.float(Double.infinity))
  let encoder = JSONEncoder()
  let data = try encoder.encode(json)
  let string = String(data: data, encoding: .utf8)!
  #expect(string == "null" || string == "[null]")
}

@Test func nanFloatThroughOrderedJSONEncoder() throws {
  // OrderedJSONEncoder should also encode NaN as null
  let json = JSON.number(.float(Double.nan))
  let encoder = OrderedJSONEncoder()
  let encoded = try encoder.encode(json)
  #expect(encoded.isNull)
}
