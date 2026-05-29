import Foundation
import Testing

@testable import OrderedJSON

// MARK: - JSON Codable conformance

struct JSONCodableConformanceTests {
  @Test("codable encode json object") func codableEncodeJSONObject() throws {
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

  @Test("codable encode json array") func codableEncodeJSONArray() throws {
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

  @Test("codable encode json scalar") func codableEncodeJSONScalar() throws {
    let json = JSON.string("hello")
    let data = try JSONEncoder().encode(json)
    let decoded = try JSONDecoder().decode(JSON.self, from: data)
    #expect(decoded == .string("hello"))
  }

  @Test("codable encode json null") func codableEncodeJSONNull() throws {
    let json = JSON.null
    let data = try JSONEncoder().encode(json)
    let decoded = try JSONDecoder().decode(JSON.self, from: data)
    #expect(decoded == .null)
  }

  @Test("codable encode json number") func codableEncodeJSONNumber() throws {
    let intJson = JSON.number(.integer(42))
    let intData = try JSONEncoder().encode(intJson)
    let intDecoded = try JSONDecoder().decode(JSON.self, from: intData)
    #expect(intDecoded.isInteger)

    let floatJson = JSON.number(.float(3.14))
    let floatData = try JSONEncoder().encode(floatJson)
    let floatDecoded = try JSONDecoder().decode(JSON.self, from: floatData)
    #expect(floatDecoded.isFloat)
  }
}

// MARK: - OrderedJSONEncoder

struct OrderedJSONEncoderTests {
  @Test("ordered encoder simple struct") func orderedEncoderSimpleStruct() throws {
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

  @Test("ordered encoder preserves key order") func orderedEncoderPreservesKeyOrder() throws {
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

  @Test("ordered encoder nested") func orderedEncoderNested() throws {
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
        address: Address(city: "NYC", zip: "10001")
      )
    )
    #expect(json["name"] == .string("Alice"))
    #expect(json["address"]?.isObject == true)
    #expect(json["address"]?["city"] == .string("NYC"))
    #expect(json["address"]?["zip"] == .string("10001"))
  }

  @Test("ordered encoder array") func orderedEncoderArray() throws {
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(["a", "b", "c"])
    #expect(json.isArray)
    #expect(json.count == 3)
    #expect(json[0] == .string("a"))
  }

  @Test("ordered encoder to string") func orderedEncoderToString() throws {
    struct Item: Encodable {
      let id: Int
      let value: String
    }
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString(Item(id: 1, value: "test"))
    #expect(str == #"{"id":1,"value":"test"}"#)
  }
}

// MARK: - OrderedJSONDecoder

struct OrderedJSONDecoderTests {
  @Test("ordered decoder from json") func orderedDecoderFromJSON() throws {
    let json = JSON.object([
      "name": .string("Alice"),
      "age": .number(.integer(30)),
    ])
    let decoder = OrderedJSONDecoder()
    let decoded: JSON = try decoder.decode(JSON.self, from: json)
    #expect(decoded == json)
  }

  @Test("ordered decoder from data") func orderedDecoderFromData() throws {
    let jsonString = #"{"name": "Bob", "age": 25}"#
    let data = Data(jsonString.utf8)
    let decoder = OrderedJSONDecoder()
    let decoded: JSON = try decoder.decode(JSON.self, from: data)
    #expect(decoded["name"] == .string("Bob"))
    #expect(decoded["age"] == .number(.integer(25)))
  }

  @Test("ordered decoder from string") func orderedDecoderFromString() throws {
    let decoder = OrderedJSONDecoder()
    let decoded: JSON = try decoder.decode(JSON.self, from: #"{"x": 1}"#)
    #expect(decoded["x"] == .number(.integer(1)))
  }

  @Test("ordered decoder preserves key order") func orderedDecoderPreservesKeyOrder() throws {
    let jsonString = #"{"z": 1, "a": 2, "m": 3}"#
    let decoder = OrderedJSONDecoder()
    let decoded: JSON = try decoder.decode(JSON.self, from: jsonString)
    let keys = decoded.keys
    #expect(keys?[0] == "z")
    #expect(keys?[1] == "a")
    #expect(keys?[2] == "m")
  }

  @Test("ordered decoder struct") func orderedDecoderStruct() throws {
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
}

// MARK: - JSONWithUnknownKeys

struct JSONWithExtrasTests {
  @Test("json with extras decode") func jsonWithExtrasDecode() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    let jsonString = #"""
      {"name": "Alice", "age": 30, "color": "blue", "city": "NYC"}
      """#
    let decoder = OrderedJSONDecoder()
    let wrapped = try decoder.decode(JSONWithUnknownKeys<Person>.self, from: jsonString)
    #expect(wrapped.value.name == "Alice")
    #expect(wrapped.value.age == 30)
    #expect(wrapped.unknownKeys["color"] == .string("blue"))
    #expect(wrapped.unknownKeys["city"] == .string("NYC"))
  }

  @Test("json with extras encode") func jsonWithExtrasEncode() throws {
    struct Person: Codable {
      let name: String
      let age: Int
    }
    let extras = JSON.object([
      "color": .string("blue"),
      "city": .string("NYC"),
    ])
    let wrapped = JSONWithUnknownKeys(
      value: Person(name: "Alice", age: 30),
      unknownKeys: extras
    )
    let encoder = JSONEncoder()
    let data = try encoder.encode(wrapped)
    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(JSONWithUnknownKeys<Person>.self, from: data)
    #expect(back.value.name == "Alice")
    #expect(back.value.age == 30)
  }

  @Test("json with extras no extras") func jsonWithExtrasNoExtras() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    let jsonString = #"{"name": "Alice", "age": 30}"#
    let decoder = OrderedJSONDecoder()
    let wrapped = try decoder.decode(JSONWithUnknownKeys<Person>.self, from: jsonString)
    #expect(wrapped.value.name == "Alice")
    #expect(wrapped.value.age == 30)
    #expect(wrapped.unknownKeys.isEmpty)
  }

  @Test("json with extras contains marks accessed") func jsonWithExtrasContainsMarksAccessed() throws {
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
    let decoded = try decoder.decode(JSONWithUnknownKeys<TestStruct>.self, from: json)
    #expect(decoded.value.x == "hello")
    #expect(decoded.value.y == "world")
    // 'z' was never accessed via contains or decode, so it appears in extras
    #expect(decoded.unknownKeys["z"] == .string("extra"))
  }

  @Test("json with extras date strategy propagated") func jsonWithExtrasDateStrategyPropagated() throws {
    // Regression: date/data/decimal strategies must propagate to the tracking decoder
    struct Person: Decodable {
      let name: String
      let birth: Date
    }
    let json = JSON.object([
      "name": .string("Alice"),
      "birth": .number(.float(1_234_567_890.0)),  // seconds since 1970
      "extra": .string("extra_key"),
    ])
    var decoder = OrderedJSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let decoded = try decoder.decode(JSONWithUnknownKeys<Person>.self, from: json)
    #expect(decoded.value.name == "Alice")
    #expect(decoded.value.birth.timeIntervalSince1970 == 1_234_567_890.0)
    #expect(decoded.unknownKeys["extra"] == .string("extra_key"))
  }

  @Test("json with extras data strategy propagated") func jsonWithExtrasDataStrategyPropagated() throws {
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
    let decoded = try decoder.decode(JSONWithUnknownKeys<Container>.self, from: json)
    #expect(decoded.value.data == Data([72, 101, 108, 108, 111]))  // "Hello" bytes
    #expect(decoded.unknownKeys["extra"] == .number(.integer(42)))
  }

  @Test("json with extras decimal strategy propagated") func jsonWithExtrasDecimalStrategyPropagated() throws {
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
    let decoded = try decoder.decode(JSONWithUnknownKeys<Container>.self, from: json)
    #expect(decoded.value.amount == Decimal(string: "3.14"))
    #expect(decoded.unknownKeys["extra"] == .string("extra_key"))
  }
}

// MARK: - Throwing accessors

struct JSONCodableThrowingAccessorTests {
  @Test("string value success") func stringValueSuccess() throws {
    let json = JSON.string("hello")
    #expect(try json.requireString() == "hello")
  }

  @Test("string value throws") func stringValueThrows() {
    let json = JSON.number(.integer(42))
    let error = #expect(throws: JSONError.self) {
      try json.requireString()
    }
    #expect(error == JSONError.typeError(expected: "string", actual: "number"))
  }

  @Test("bool value success") func boolValueSuccess() throws {
    let json = JSON.boolean(true)
    #expect(try json.requireBool() == true)
  }

  @Test("require int64 value success") func requireInt64ValueSuccess() throws {
    let json = JSON.number(.integer(42))
    #expect(try json.requireInt64() == 42)
  }

  @Test("double value success") func doubleValueSuccess() throws {
    let json = JSON.number(.float(3.14))
    #expect(try json.requireDouble() == 3.14)
  }
}

// MARK: - Convenience decode

struct JSONConvenienceDecodeTests {
  @Test("convenience decode from string") func convenienceDecodeFromString() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    let person = try JSON.decode(Person.self, from: "{\"name\": \"Alice\", \"age\": 30}")
    #expect(person.name == "Alice")
    #expect(person.age == 30)
  }

  @Test("convenience decode from data") func convenienceDecodeFromData() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    let data = Data("{\"name\": \"Bob\", \"age\": 25}".utf8)
    let person = try JSON.decode(Person.self, from: data)
    #expect(person.name == "Bob")
    #expect(person.age == 25)
  }

  @Test("convenience decode json") func convenienceDecodeJSON() throws {
    let json: JSON = try JSON.decode(JSON.self, from: "{\"x\": 1, \"y\": 2}")
    #expect(json["x"] == .number(.integer(1)))
    #expect(json["y"] == .number(.integer(2)))
  }
}

// MARK: - Number normalization

struct JSONNumberNormalizationTests {
  @Test("number normalization clean double") func numberNormalizationCleanDouble() throws {
    let data = Data("42.0".utf8)
    let decoded = try JSONDecoder().decode(JSON.self, from: data)
    #expect(decoded.isInteger)
    #expect(decoded == .number(.integer(42)))
  }

  @Test("number normalization fractional double") func numberNormalizationFractionalDouble() throws {
    let data = Data("3.14".utf8)
    let decoded = try JSONDecoder().decode(JSON.self, from: data)
    #expect(decoded.isFloat)
  }

  @Test("number normalization large integer") func numberNormalizationLargeInteger() throws {
    let data = Data("1.0e20".utf8)
    let decoded = try JSONDecoder().decode(JSON.self, from: data)
    #expect(decoded.isFloat)
  }
}

// MARK: - Integer and unsigned width accessors

struct JSONIntegerWidthTests {
  @Test("require int8 value success") func requireInt8ValueSuccess() throws {
    let json = JSON.number(.integer(42))
    #expect(try json.requireInt8() == 42)
  }

  @Test("require int8 value overflow") func requireInt8ValueOverflow() throws {
    let json = JSON.number(.integer(200))
    let error = #expect(throws: JSONError.self) {
      try json.requireInt8()
    }
    #expect(error == JSONError.typeError(expected: "int8", actual: "number"))
  }

  @Test("require int16 value success") func requireInt16ValueSuccess() throws {
    let json = JSON.number(.integer(300))
    #expect(try json.requireInt16() == 300)
  }

  @Test("require int32 value success") func requireInt32ValueSuccess() throws {
    let json = JSON.number(.integer(100_000))
    #expect(try json.requireInt32() == 100_000)
  }

  @Test("require uint value success") func requireUIntValueSuccess() throws {
    let json = JSON.number(.integer(42))
    #expect(try json.requireUInt() == 42)
  }

  @Test("require uint value negative throws") func requireUIntValueNegativeThrows() throws {
    let json = JSON.number(.integer(-1))
    let error = #expect(throws: JSONError.self) {
      try json.requireUInt()
    }
    #expect(error == JSONError.typeError(expected: "uint", actual: "number"))
  }

  @Test("require uint8 value success") func requireUInt8ValueSuccess() throws {
    let json = JSON.number(.integer(255))
    #expect(try json.requireUInt8() == 255)
  }

  @Test("require uint8 value overflow") func requireUInt8ValueOverflow() throws {
    let json = JSON.number(.integer(256))
    let error = #expect(throws: JSONError.self) {
      try json.requireUInt8()
    }
    #expect(error == JSONError.typeError(expected: "uint8", actual: "number"))
  }

  @Test("require uint16 value success") func requireUInt16ValueSuccess() throws {
    let json = JSON.number(.integer(42000))
    #expect(try json.requireUInt16() == 42000)
  }

  @Test("require uint32 value success") func requireUInt32ValueSuccess() throws {
    let json = JSON.number(.integer(2_000_000_000))
    #expect(try json.requireUInt32() == 2_000_000_000)
  }

  @Test("require uint64 value success") func requireUInt64ValueSuccess() throws {
    let json = JSON.number(.integer(42))
    #expect(try json.requireUInt64() == 42)
  }

  @Test("require uint64 value negative throws") func requireUInt64ValueNegativeThrows() throws {
    let json = JSON.number(.integer(-1))
    let error = #expect(throws: JSONError.self) {
      try json.requireUInt64()
    }
    #expect(error == JSONError.typeError(expected: "uint64", actual: "number"))
  }

  @Test("double value from integer") func doubleValueFromInteger() throws {
    let json = JSON.number(.integer(42))
    #expect(try json.requireDouble() == 42.0)
  }

  @Test("double value from float") func doubleValueFromFloat() throws {
    let json = JSON.number(.float(3.14))
    #expect(try json.requireDouble() == 3.14)
  }

  @Test("double value throws on non number") func doubleValueThrowsOnNonNumber() throws {
    let json = JSON.string("hello")
    let error = #expect(throws: JSONError.self) {
      try json.requireDouble()
    }
    #expect(error == JSONError.typeError(expected: "float", actual: "string"))
  }

  @Test("require float value rejects lossy double") func requireFloatValueRejectsLossyDouble() throws {
    // 0.1 is not exactly representable as Float
    let json = JSON.number(.float(0.1))
    let error = #expect(throws: JSONError.self) {
      try json.requireFloat()
    }
    #expect(error == JSONError.typeError(expected: "float", actual: "double"))
  }

  @Test("require float value from integer") func requireFloatValueFromInteger() throws {
    // Clean integers are exactly representable as Float
    let json = JSON.number(.integer(42))
    #expect(try json.requireFloat() == 42.0)
  }

  @Test("require int64 value from float") func requireInt64ValueFromFloat() throws {
    // Clean integer stored as .float should still work with int64Value
    let json = JSON.number(.float(42.0))
    #expect(try json.requireInt64() == 42)
  }

  @Test("require int64 value from float throws") func requireInt64ValueFromFloatThrows() throws {
    // Fractional float should throw
    let json = JSON.number(.float(3.14))
    let error = #expect(throws: JSONError.self) {
      try json.requireInt64()
    }
    #expect(error == JSONError.typeError(expected: "integer", actual: "number"))
  }
}

// MARK: - Integer and unsigned width encoding/decoding

struct JSONIntegerWidthCodingTests {
  @Test("encode decode int8") func encodeDecodeInt8() throws {
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

  @Test("encode decode int16") func encodeDecodeInt16() throws {
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

  @Test("encode decode int32") func encodeDecodeInt32() throws {
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

  @Test("encode decode uint") func encodeDecodeUInt() throws {
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

  @Test("encode decode uint8") func encodeDecodeUInt8() throws {
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

  @Test("encode decode uint16") func encodeDecodeUInt16() throws {
    struct Value: Codable {
      let x: UInt16
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Value(x: 42000))
    #expect(json["x"] == .number(.integer(42000)))

    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Value.self, from: json)
    #expect(back.x == 42000)
  }

  @Test("encode decode uint32") func encodeDecodeUInt32() throws {
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

  @Test("encode decode uint64") func encodeDecodeUInt64() throws {
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

  @Test("encode uint64 overflow throws") func encodeUInt64OverflowThrows() throws {
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
}

// MARK: - Optional / decodeIfPresent

struct JSONDecodeIfPresentTests {
  @Test("decode if present present") func decodeIfPresentPresent() throws {
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

  @Test("decode if present missing") func decodeIfPresentMissing() throws {
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

  @Test("decode if present explicit null") func decodeIfPresentExplicitNull() throws {
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

  @Test("decode if present missing with extras") func decodeIfPresentMissingWithExtras() throws {
    struct Person: Decodable {
      let name: String
      let age: Int?
    }
    let json = #"{"name": "Alice", "color": "blue"}"#
    let decoder = OrderedJSONDecoder()
    let wrapped = try decoder.decode(JSONWithUnknownKeys<Person>.self, from: json)
    #expect(wrapped.value.name == "Alice")
    #expect(wrapped.value.age == nil)
    #expect(wrapped.unknownKeys["color"] == .string("blue"))
  }
}

// MARK: - Round-trip via OrderedJSONEncoder → dump → parse → OrderedJSONDecoder

struct JSONRoundTripTests {
  @Test("ordered json encoder decoder round trip") func orderedJSONEncoderDecoderRoundTrip() throws {
    struct Person: Codable {
      let name: String
      let age: Int
    }
    let original = Person(name: "Alice", age: 30)
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(original)
    let jsonString = json.dump(indent: nil)
    let parsed = try JSON.parse(jsonString)
    let decoder = OrderedJSONDecoder()
    let roundTripped = try decoder.decode(Person.self, from: parsed)
    #expect(roundTripped.name == "Alice")
    #expect(roundTripped.age == 30)
  }

  @Test("ordered json encoder decoder array round trip") func orderedJSONEncoderDecoderArrayRoundTrip() throws {
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode([1, 2, 3])
    let jsonString = json.dump(indent: nil)
    let parsed = try JSON.parse(jsonString)
    let decoder = OrderedJSONDecoder()
    let arr = try decoder.decode([Int].self, from: parsed)
    #expect(arr == [1, 2, 3])
  }

  @Test("ordered json encoder decoder nested round trip") func orderedJSONEncoderDecoderNestedRoundTrip() throws {
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
      address: Address(city: "NYC", zip: "10001")
    )
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(original)
    let jsonString = json.dump(indent: nil)
    let parsed = try JSON.parse(jsonString)
    let decoder = OrderedJSONDecoder()
    let roundTripped = try decoder.decode(Person.self, from: parsed)
    #expect(roundTripped.name == "Alice")
    #expect(roundTripped.address.city == "NYC")
    #expect(roundTripped.address.zip == "10001")
  }
}

// MARK: - Nested container via explicit nestedContainer(keyedBy:forKey:)

struct JSONNestedContainerTests {
  @Test("explicit nested container encode") func explicitNestedContainerEncode() throws {
    struct Inner: Encodable {
      let x: Int
    }
    struct Outer: Encodable {
      let inner: Inner

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var nested = container.nestedContainer(
          keyedBy: InnerKeys.self, forKey: .inner
        )
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

  @Test("explicit nested unkeyed container encode") func explicitNestedUnkeyedContainerEncode() throws {
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
}

// MARK: - Key order preservation through OrderedJSONDecoder

struct JSONKeyOrderTests {
  @Test("ordered decoder key order for struct") func orderedDecoderKeyOrderForStruct() throws {
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
    _ = try decoder.decode(Ordered.self, from: jsonString)
  }
}

// MARK: - JSONWithUnknownKeys: extras must be object

struct JSONWithExtrasValidationTests {
  @Test("json with extras non object extras throws on encode") func jsonWithExtrasNonObjectExtrasThrowsOnEncode() throws {
    struct Person: Codable {
      let name: String
    }
    let wrapped = JSONWithUnknownKeys(
      value: Person(name: "Alice"),
      unknownKeys: .null
    )
    let encoder = JSONEncoder()
    #expect {
      try encoder.encode(wrapped)
    } throws: { error in
      guard let encodingError = error as? EncodingError else { return false }
      switch encodingError {
      case .invalidValue(_, let ctx):
        return ctx.debugDescription.contains("Unknown keys must be a JSON object")
      default: return false
      }
    }
  }
}

// MARK: - Coding path propagation

struct JSONCodingPathTests {
  @Test("coding path includes keys") func codingPathIncludesKeys() throws {
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
}

// MARK: - Super encoder

struct JSONSuperEncoderTests {
  @Test("super encoder writes under super key") func superEncoderWritesUnderSuperKey() throws {
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
}

// MARK: - Top-level JSON.encode(_:) and JSON.decode(_:from:) convenience

struct JSONTopLevelConvenienceTests {
  @Test("top level encode struct") func topLevelEncodeStruct() throws {
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

  @Test("top level encode array") func topLevelEncodeArray() throws {
    let json = try JSON.encode([1, 2, 3])
    #expect(json.isArray)
    #expect(json.count == 3)
    #expect(json[0] == .number(.integer(1)))
    #expect(json[1] == .number(.integer(2)))
    #expect(json[2] == .number(.integer(3)))
  }

  @Test("top level encode string") func topLevelEncodeString() throws {
    let json = try JSON.encode("hello")
    #expect(json.isString)
    #expect(json == .string("hello"))
  }

  @Test("top level decode from json") func topLevelDecodeFromJSON() throws {
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

  @Test("top level decode json type") func topLevelDecodeJSONType() throws {
    let json = JSON.object(["x": .number(.integer(1)), "y": .number(.integer(2))])
    let decoded: JSON = try JSON.decode(JSON.self, from: json)
    #expect(decoded["x"] == .number(.integer(1)))
    #expect(decoded["y"] == .number(.integer(2)))
  }

  @Test("top level encode decode round trip") func topLevelEncodeDecodeRoundTrip() throws {
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

  @Test("top level encode preserves key order") func topLevelEncodePreservesKeyOrder() throws {
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
}

// MARK: - Foundation type interop

struct JSONFoundationInteropTests {
  @Test("foundation date default") func foundationDateDefault() throws {
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

  @Test("foundation date seconds since 1970") func foundationDateSecondsSince1970() throws {
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

  @Test("foundation date milliseconds since 1970") func foundationDateMillisecondsSince1970() throws {
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

  @Test("foundation date iso8601") func foundationDateISO8601() throws {
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

  @Test("foundation date formatted") func foundationDateFormatted() throws {
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

  @Test("foundation data base64") func foundationDataBase64() throws {
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

  @Test("foundation url") func foundationURL() throws {
    struct Container: Codable {
      let url: URL
    }
    let url = try #require(URL(string: "https://example.com/path"))
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Container(url: url))
    #expect(json["url"] == .string(url.absoluteString))

    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Container.self, from: json)
    #expect(back.url == url)
  }

  @Test("foundation uuid") func foundationUUID() throws {
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

  @Test("foundation decimal") func foundationDecimal() throws {
    struct Container: Codable {
      let amount: Decimal
    }
    let decimal = try #require(Decimal(string: "3.14159"))
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Container(amount: decimal))
    #expect(json["amount"]?.isString == true)
    #expect(json["amount"]?.stringValue == "3.14159")

    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Container.self, from: json)
    #expect(back.amount == decimal)
  }

  @Test("foundation decimal as number") func foundationDecimalAsNumber() throws {
    struct Container: Codable {
      let amount: Decimal
    }
    let decimal = try #require(Decimal(string: "3.14159"))
    var encoder = OrderedJSONEncoder()
    encoder.decimalEncodingStrategy = .asNumber
    let json = try encoder.encode(Container(amount: decimal))
    #expect(json["amount"]?.isNumber == true)
    var decoder = OrderedJSONDecoder()
    decoder.decimalDecodingStrategy = .asNumber
    let back = try decoder.decode(Container.self, from: json)
    #expect(back.amount == decimal)
  }

  @Test("foundation decimal as number huge throws") func foundationDecimalAsNumberHugeThrows() throws {
    // Regression test: Decimal with huge exponent must not cause Int64(Double.infinity) crash
    struct Container: Codable {
      let amount: Decimal
    }
    // A Decimal with exponent that overflows Double to infinity
    let huge = Decimal(sign: .plus, exponent: 400, significand: 1)
    var encoder = OrderedJSONEncoder()
    encoder.decimalEncodingStrategy = .asNumber
    // Should throw EncodingError, not crash
    #expect(throws: EncodingError.self) {
      try encoder.encode(Container(amount: huge))
    }
  }

  @Test("foundation date custom strategy") func foundationDateCustomStrategy() throws {
    struct Container: Codable {
      let timestamp: Date
    }
    let date = Date(timeIntervalSince1970: 42)
    var encoder = OrderedJSONEncoder()
    encoder.dateEncodingStrategy = .custom { d, _ in
      .object(["epoch": .number(.integer(Int64(d.timeIntervalSince1970)))])
    }
    let json = try encoder.encode(Container(timestamp: date))
    #expect(json["timestamp"]?.isObject == true)
    #expect(json["timestamp"]?["epoch"] == .number(.integer(42)))

    var decoder = OrderedJSONDecoder()
    decoder.dateDecodingStrategy = .custom { json, _ in
      try Date(timeIntervalSince1970: json["epoch"]!.requireDouble())
    }
    let back = try decoder.decode(Container.self, from: json)
    #expect(back.timestamp.timeIntervalSince1970 == 42)
  }

  @Test("foundation data custom strategy") func foundationDataCustomStrategy() throws {
    struct Container: Codable {
      let data: Data
    }
    let original = Data([0x01, 0x02])
    var encoder = OrderedJSONEncoder()
    encoder.dataEncodingStrategy = .custom { d, _ in
      .number(.integer(Int64(d.count)))
    }
    let json = try encoder.encode(Container(data: original))
    #expect(json["data"] == .number(.integer(2)))

    var decoder = OrderedJSONDecoder()
    decoder.dataDecodingStrategy = .custom { _, _ in
      Data([0x01, 0x02])
    }
    let back = try decoder.decode(Container.self, from: json)
    #expect(back.data == original)
  }
}

// MARK: - Invalid input error handling

struct JSONInvalidInputTests {
  @Test("invalid url string throws") func invalidURLStringThrows() throws {
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

  @Test("invalid uuid string throws") func invalidUUIDStringThrows() throws {
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

  @Test("invalid decimal string throws") func invalidDecimalStringThrows() throws {
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

  @Test("invalid decimal as number throws") func invalidDecimalAsNumberThrows() throws {
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
}

// MARK: - Optional Date via decodeIfPresent

struct JSONOptionalDateTests {
  @Test("foundation optional date present") func foundationOptionalDatePresent() throws {
    struct Container: Decodable {
      let timestamp: Date?
    }
    let decoder = OrderedJSONDecoder()
    let json = JSON.object(["timestamp": .number(.float(0))])
    let back = try decoder.decode(Container.self, from: json)
    #expect(back.timestamp != nil)
  }

  @Test("foundation optional date missing") func foundationOptionalDateMissing() throws {
    struct Container: Decodable {
      let timestamp: Date?
    }
    let decoder = OrderedJSONDecoder()
    let json = JSON.object([:])
    let back = try decoder.decode(Container.self, from: json)
    #expect(back.timestamp == nil)
  }

  @Test("foundation optional date explicit null") func foundationOptionalDateExplicitNull() throws {
    struct Container: Decodable {
      let timestamp: Date?
    }
    let decoder = OrderedJSONDecoder()
    let json = JSON.object(["timestamp": .null])
    let back = try decoder.decode(Container.self, from: json)
    #expect(back.timestamp == nil)
  }
}

// MARK: - Strategy propagation through custom closures

struct JSONStrategyPropagationTests {
  @Test("strategy propagation in deferred date") func strategyPropagationInDeferredDate() throws {
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
    let decimal = try #require(Decimal(string: "2.71828"))
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

  @Test("foundation date in unkeyed container") func foundationDateInUnkeyedContainer() throws {
    struct Container: Decodable {
      let dates: [Date]
    }
    var decoder = OrderedJSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let json = JSON.object(["dates": .array([.number(.float(1000)), .number(.float(2000))])])
    let back = try decoder.decode(Container.self, from: json)
    #expect(back.dates.count == 2)
    #expect(back.dates[0].timeIntervalSince1970 == 1000)
    #expect(back.dates[1].timeIntervalSince1970 == 2000)
  }

  @Test("decode double near int64 max") func decodeDoubleNearInt64Max() throws {
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

  @Test("decode large double stays float") func decodeLargeDoubleStaysFloat() throws {
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

  @Test("decode negative double near int64 min") func decodeNegativeDoubleNearInt64Min() throws {
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

  @Test("nan float through json encoder") func nanFloatThroughJSONEncoder() throws {
    // JSON.number(.float(NaN)) encodes as null via JSON: Encodable
    let json = JSON.number(.float(Double.nan))
    let encoder = JSONEncoder()
    let data = try encoder.encode(json)
    let string = try #require(String(data: data, encoding: .utf8))
    #expect(string == "null" || string == "[null]")
  }

  @Test("infinity float through json encoder") func infinityFloatThroughJSONEncoder() throws {
    // JSON.number(.float(Infinity)) encodes as null via JSON: Encodable
    let json = JSON.number(.float(Double.infinity))
    let encoder = JSONEncoder()
    let data = try encoder.encode(json)
    let string = try #require(String(data: data, encoding: .utf8))
    #expect(string == "null" || string == "[null]")
  }

  @Test("nan float through ordered json encoder") func nanFloatThroughOrderedJSONEncoder() throws {
    // OrderedJSONEncoder should also encode NaN as null
    let json = JSON.number(.float(Double.nan))
    let encoder = OrderedJSONEncoder()
    let encoded = try encoder.encode(json)
    #expect(encoded.isNull)
  }
}

// MARK: - Helper: JSON keys

extension JSON {
  /// Returns the keys of an object in insertion order, or nil if not an object.
  fileprivate var keys: [String]? {
    guard case .object(let dict) = storage else { return nil }
    return Array(dict.keys)
  }
}
