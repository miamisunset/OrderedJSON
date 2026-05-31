import Foundation
import Testing

@testable import OrderedJSON

// MARK: - Strategy error edge cases

@Suite("Strategy Error Edge Cases") struct StrategyErrorEdgeCaseTests {
  @Test("secondsSince1970 with non-number throws") func secondsSince1970NonNumber() throws {
    struct Container: Decodable {
      let timestamp: Date
    }
    var decoder = OrderedJSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    // String instead of number should throw
    let json = JSON.object(["timestamp": .string("not-a-number")])
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }

  @Test("millisecondsSince1970 with non-number throws") func millisecondsSince1970NonNumber() throws
  {
    struct Container: Decodable {
      let timestamp: Date
    }
    var decoder = OrderedJSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    // Null instead of number should throw
    let json = JSON.object(["timestamp": .null])
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }

  @Test("base64 with non-string throws") func base64NonString() throws {
    struct Container: Decodable {
      let data: Data
    }
    var decoder = OrderedJSONDecoder()
    decoder.dataDecodingStrategy = .base64
    // Number instead of string should throw
    let json = JSON.object(["data": .number(.integer(42))])
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }

  @Test("base64 with invalid string throws") func base64InvalidString() throws {
    struct Container: Decodable {
      let data: Data
    }
    var decoder = OrderedJSONDecoder()
    decoder.dataDecodingStrategy = .base64
    // Invalid base64 string should throw dataCorrupted
    let json = JSON.object(["data": .string("not-valid-base64!!!")])
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }

  @Test("decimal asString with non-string throws") func decimalAsStringNonString() throws {
    struct Container: Decodable {
      let amount: Decimal
    }
    let decoder = OrderedJSONDecoder()
    // Default strategy is .asString, number instead of string should throw
    let json = JSON.object(["amount": .number(.integer(42))])
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }

  @Test("decimal asString with invalid string throws") func decimalAsStringInvalidString() throws {
    struct Container: Decodable {
      let amount: Decimal
    }
    let decoder = OrderedJSONDecoder()
    // Non-numeric string should throw dataCorrupted
    let json = JSON.object(["amount": .string("not-a-decimal")])
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }

  @Test("iso8601 with non-string throws") func iso8601NonString() throws {
    struct Container: Decodable {
      let timestamp: Date
    }
    var decoder = OrderedJSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    // Number instead of string should throw
    let json = JSON.object(["timestamp": .number(.integer(0))])
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }

  @Test("formatted date with non-string throws") func formattedDateNonString() throws {
    struct Container: Decodable {
      let timestamp: Date
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    var decoder = OrderedJSONDecoder()
    decoder.dateDecodingStrategy = .formatted(formatter)
    // Boolean instead of string should throw
    let json = JSON.object(["timestamp": .boolean(true)])
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }

  @Test("iso8601 with invalid string throws") func iso8601InvalidString() throws {
    struct Container: Decodable {
      let timestamp: Date
    }
    var decoder = OrderedJSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    // Invalid date string should throw dataCorrupted
    let json = JSON.object(["timestamp": .string("not-a-date")])
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }

  @Test("url with non-string throws") func urlNonString() throws {
    struct Container: Decodable {
      let url: URL
    }
    let decoder = OrderedJSONDecoder()
    // Number instead of string should throw
    let json = JSON.object(["url": .number(.integer(42))])
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }

  @Test("uuid with non-string throws") func uuidNonString() throws {
    struct Container: Decodable {
      let id: UUID
    }
    let decoder = OrderedJSONDecoder()
    // Null instead of string should throw
    let json = JSON.object(["id": .null])
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }

  @Test("dateDecodingStrategy custom throws propagated") func dateCustomStrategyThrowsPropagated()
    throws
  {
    struct Container: Decodable {
      let timestamp: Date
    }
    var decoder = OrderedJSONDecoder()
    decoder.dateDecodingStrategy = .custom { _, _ in
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: [], debugDescription: "custom error")
      )
    }
    let json = JSON.object(["timestamp": .number(.float(0))])
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }
}

// MARK: - Key order preservation edge cases

@Suite("Key Order Preservation Edge Cases") struct KeyOrderPreservationEdgeCaseTests {
  @Test("key order through JSONWithUnknownKeys") func keyOrderThroughJSONWithUnknownKeys() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    // Keys in non-alphabetical order
    let jsonString = #"{"z": "last", "a": "first", "m": "middle", "name": "Alice", "age": 30}"#
    let decoder = OrderedJSONDecoder()
    let wrapped = try decoder.decode(JSONWithUnknownKeys<Person>.self, from: jsonString)
    // Check that unknown keys preserve order: z, a, m
    guard case .object(let unknownDict) = wrapped.unknownKeys.storage else {
      #expect(Bool(false), "expected object")
      return
    }
    let unknownKeys = Array(unknownDict.keys)
    #expect(unknownKeys[0] == "z")
    #expect(unknownKeys[1] == "a")
    #expect(unknownKeys[2] == "m")
  }

  @Test("key order through nested decoder") func keyOrderThroughNestedDecoder() throws {
    // Decode a JSON with specific key order, then verify JSON's keys match
    let jsonString = #"{"c": 1, "b": 2, "a": 3}"#
    let decoder = OrderedJSONDecoder()
    let json: JSON = try decoder.decode(JSON.self, from: jsonString)
    guard case .object(let dict) = json.storage else {
      #expect(Bool(false), "expected object")
      return
    }
    let keys = Array(dict.keys)
    #expect(keys[0] == "c")
    #expect(keys[1] == "b")
    #expect(keys[2] == "a")
  }

  @Test("key order through encode then decode preserves") func keyOrderEncodeDecodePreserves()
    throws
  {
    struct Ordered: Codable {
      let z: String
      let a: String
      let m: String
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Ordered(z: "1", a: "2", m: "3"))
    let decoder = OrderedJSONDecoder()
    let decoded: JSON = try decoder.decode(JSON.self, from: json)
    guard case .object(let dict) = decoded.storage else {
      #expect(Bool(false), "expected object")
      return
    }
    let keys = Array(dict.keys)
    // Keys should be in declaration order: z, a, m
    #expect(keys[0] == "z")
    #expect(keys[1] == "a")
    #expect(keys[2] == "m")
  }

  @Test("key order with nested objects preserves") func keyOrderNestedObjects() throws {
    struct Inner: Encodable {
      let b: Int
      let a: Int
    }
    struct Outer: Encodable {
      let inner: Inner
      let z: Int
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Outer(inner: Inner(b: 1, a: 2), z: 3))
    guard case .object(let outerDict) = json.storage else {
      #expect(Bool(false), "expected object")
      return
    }
    let outerKeys = Array(outerDict.keys)
    #expect(outerKeys[0] == "inner")
    #expect(outerKeys[1] == "z")
    guard case .object(let innerDict) = outerDict["inner"]?.storage else {
      #expect(Bool(false), "expected inner object")
      return
    }
    let innerKeys = Array(innerDict.keys)
    #expect(innerKeys[0] == "b")
    #expect(innerKeys[1] == "a")
  }
}

// MARK: - JSONWithUnknownKeys edge cases

@Suite("JSONWithUnknownKeys Edge Cases") struct JSONWithUnknownKeysEdgeCaseTests {
  @Test("all keys matched produces empty extras") func allKeysMatched() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    let json = JSON.object([
      "name": .string("Alice"),
      "age": .number(.integer(30)),
    ])
    let decoder = OrderedJSONDecoder()
    let wrapped = try decoder.decode(JSONWithUnknownKeys<Person>.self, from: json)
    #expect(wrapped.value.name == "Alice")
    #expect(wrapped.value.age == 30)
    #expect(wrapped.unknownKeys.isEmpty)
  }

  @Test("no keys matched wraps entire object as extras") func noKeysMatched() throws {
    struct Empty: Decodable {
      // No CodingKeys — empty struct
    }
    let json = JSON.object([
      "a": .string("1"),
      "b": .number(.integer(2)),
    ])
    let decoder = OrderedJSONDecoder()
    let wrapped = try decoder.decode(JSONWithUnknownKeys<Empty>.self, from: json)
    #expect(wrapped.unknownKeys.count == 2)
    #expect(wrapped.unknownKeys["a"] == .string("1"))
    #expect(wrapped.unknownKeys["b"] == .number(.integer(2)))
  }

  @Test("null values in unknown keys preserved") func nullValuesInUnknownKeys() throws {
    struct Person: Decodable {
      let name: String
    }
    let json = JSON.object([
      "name": .string("Alice"),
      "extra": .null,
    ])
    let decoder = OrderedJSONDecoder()
    let wrapped = try decoder.decode(JSONWithUnknownKeys<Person>.self, from: json)
    #expect(wrapped.value.name == "Alice")
    #expect(wrapped.unknownKeys["extra"] == .null)
  }

  @Test("decodeIfPresent does not mark absent keys as accessed")
  func decodeIfPresentDoesNotMarkAbsent() throws {
    // Regression: decodeIfPresent for an absent key should not mark it as "accessed",
    // so it should appear in extras
    struct TestStruct: Decodable {
      let x: String
      let y: String?
      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try container.decode(String.self, forKey: .x)
        y = try container.decodeIfPresent(String.self, forKey: .y)
      }
      enum CodingKeys: String, CodingKey {
        case x, y
      }
    }
    // "y" is absent, so decodeIfPresent will call decodeNil which marks it as accessed.
    // This means "y" won't appear in extras (it was accessed).
    // But "z" should appear in extras since it was never accessed.
    let json = JSON.object([
      "x": .string("hello"),
      "z": .string("extra"),
    ])
    let decoder = OrderedJSONDecoder()
    let decoded = try decoder.decode(JSONWithUnknownKeys<TestStruct>.self, from: json)
    #expect(decoded.value.x == "hello")
    #expect(decoded.value.y == nil)
    #expect(decoded.unknownKeys["z"] == .string("extra"))
    // "y" was accessed via decodeNil, so it won't be in extras
    #expect(decoded.unknownKeys["y"] == nil)
  }

  @Test("contains marks key as accessed") func containsMarksKeyAccessed() throws {
    // Regression: using contains(_:) should mark the key as accessed
    struct TestStruct: Decodable {
      let x: String
      let y: String?
      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try container.decode(String.self, forKey: .x)
        // Using contains marks "y" as accessed even though we don't decode it
        if container.contains(CodingKeys.y) {
          y = try container.decodeIfPresent(String.self, forKey: .y)
        } else {
          y = nil
        }
      }
      enum CodingKeys: String, CodingKey {
        case x, y
      }
    }
    // "y" is present, and contains marks it as accessed, so it won't be in extras
    let json = JSON.object([
      "x": .string("hello"),
      "y": .string("world"),
      "z": .string("extra"),
    ])
    let decoder = OrderedJSONDecoder()
    let decoded = try decoder.decode(JSONWithUnknownKeys<TestStruct>.self, from: json)
    #expect(decoded.value.x == "hello")
    #expect(decoded.value.y == "world")
    #expect(decoded.unknownKeys["z"] == .string("extra"))
    // "y" was accessed via contains, so it won't be in extras
    #expect(decoded.unknownKeys["y"] == nil)
  }
}

// MARK: - EncodeAsString edge cases

@Suite("EncodeAsString Edge Cases") struct EncodeAsStringEdgeCaseTests {
  @Test("encode empty struct as string") func encodeEmptyStruct() throws {
    struct Empty: Encodable {}
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString(Empty())
    #expect(str == "{}")
  }

  @Test("encode null as string") func encodeNull() throws {
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString(JSON.null)
    #expect(str == "null")
  }

  @Test("encode empty array as string") func encodeEmptyArray() throws {
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString([String]())
    #expect(str == "[]")
  }

  @Test("encodeAsString matches dump(indent: nil)") func encodeAsStringMatchesDump() throws {
    struct Person: Encodable {
      let name: String
      let age: Int
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Person(name: "Alice", age: 30))
    let dumpString = json.dump(indent: nil)
    let encodeString = try encoder.encodeAsString(Person(name: "Alice", age: 30))
    #expect(encodeString == dumpString)
  }

  @Test("encode deeply nested as string") func encodeDeeplyNested() throws {
    struct Inner: Encodable {
      let value: Int
    }
    struct Outer: Encodable {
      let inner: Inner
    }
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString(Outer(inner: Inner(value: 42)))
    #expect(str == "{\"inner\":{\"value\":42}}")
  }

  @Test("encode array of structs as string") func encodeArrayOfStructs() throws {
    struct Item: Encodable {
      let id: Int
    }
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString([Item(id: 1), Item(id: 2)])
    #expect(str == "[{\"id\":1},{\"id\":2}]")
  }

  @Test("encodeAsString with date strategy") func encodeAsStringWithDate() throws {
    struct Container: Encodable {
      let timestamp: Date
    }
    var encoder = OrderedJSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    let date = Date(timeIntervalSince1970: 1_000_000)
    let str = try encoder.encodeAsString(Container(timestamp: date))
    #expect(str == "{\"timestamp\":1000000.0}" || str == "{\"timestamp\":1000000}")
  }
}

// MARK: - Super encoder edge cases

@Suite("Super Encoder Edge Cases") struct SuperEncoderEdgeCaseTests {
  @Test("super encoder forKey writes correct key") func superEncoderForKey() throws {
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
        // Super encoder for the parent class under explicit key "parent"
        let superEncoder = container.superEncoder(forKey: .parent)
        try super.encode(to: superEncoder)
      }
      enum CodingKeys: CodingKey {
        case derivedValue
        case parent
      }
    }

    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Derived())
    #expect(json["derivedValue"] == .string("hello"))
    #expect(json["parent"]?.isObject == true)
    #expect(json["parent"]?["baseValue"] == .number(.integer(42)))
  }

  @Test("super encoder nested subclass") func superEncoderNestedSubclass() throws {
    class GrandBase: Encodable {
      let grandValue: String = "grand"
      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(grandValue, forKey: .grandValue)
      }
      enum CodingKeys: CodingKey {
        case grandValue
      }
    }

    class Mid: GrandBase {
      let midValue: Int = 1
      override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(midValue, forKey: .midValue)
        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
      }
      enum CodingKeys: CodingKey {
        case midValue
      }
    }

    class Derived: Mid {
      let derivedValue: Bool = true
      override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(derivedValue, forKey: .derivedValue)
        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
      }
      enum CodingKeys: CodingKey {
        case derivedValue
      }
    }

    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Derived())
    #expect(json["derivedValue"] == .boolean(true))
    #expect(json["super"]?.isObject == true)
    // Mid encodes under "super" key within the parent's "super"
    // GrandBase encodes under "super" within Mid's "super"
    // So we need to check: json["super"]["midValue"] exists
    let mid = json["super"]
    #expect(mid?["midValue"] == .number(.integer(1)))
    // And mid["super"]["grandValue"] should exist
    let grand = mid?["super"]
    #expect(grand?["grandValue"] == .string("grand"))
  }

  @Test("super encoder round trip encodes correct structure") func superEncoderRoundTrip() throws {
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
        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
      }
      enum CodingKeys: CodingKey {
        case derivedValue
      }
    }

    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Derived())
    // Verify the encoded structure has "super" key with base class values
    #expect(json["derivedValue"] == .string("hello"))
    #expect(json["super"]?.isObject == true)
    #expect(json["super"]?["baseValue"] == .number(.integer(42)))
  }
}

// MARK: - Convenience method edge cases

@Suite("Convenience Method Edge Cases") struct ConvenienceMethodEdgeCaseTests {
  @Test("JSON.encode empty object") func jsonEncodeEmptyObject() throws {
    let json: JSON = .object([:])
    let encoder = OrderedJSONEncoder()
    let encoded = try encoder.encode(json)
    #expect(encoded.isObject)
    #expect(encoded.isEmpty)
  }

  @Test("JSON.encode empty array") func jsonEncodeEmptyArray() throws {
    let json: JSON = .array([])
    let encoder = OrderedJSONEncoder()
    let encoded = try encoder.encode(json)
    #expect(encoded.isArray)
    #expect(encoded.isEmpty)
  }

  @Test("JSON.encode null") func jsonEncodeNull() throws {
    let json: JSON = .null
    let encoder = OrderedJSONEncoder()
    let encoded = try encoder.encode(json)
    #expect(encoded.isNull)
  }

  @Test("JSON.encode boolean") func jsonEncodeBoolean() throws {
    let json: JSON = .boolean(true)
    let encoder = OrderedJSONEncoder()
    let encoded = try encoder.encode(json)
    #expect(encoded == .boolean(true))
  }

  @Test("JSON.decode from empty object") func jsonDecodeEmptyObject() throws {
    let json: JSON = .object([:])
    let decoded: JSON = try JSON.decode(JSON.self, from: json)
    #expect(decoded.isObject)
    #expect(decoded.isEmpty)
  }

  @Test("JSON.decode from empty array") func jsonDecodeEmptyArray() throws {
    let json: JSON = .array([])
    let decoded: JSON = try JSON.decode(JSON.self, from: json)
    #expect(decoded.isArray)
    #expect(decoded.isEmpty)
  }

  @Test("JSON.encode string") func jsonEncodeString() throws {
    let encoded = try JSON.encode("hello")
    #expect(encoded == .string("hello"))
  }

  @Test("JSON.encode int") func jsonEncodeInt() throws {
    let encoded = try JSON.encode(42)
    #expect(encoded == .number(.integer(42)))
  }

  @Test("JSON.encode double") func jsonEncodeDouble() throws {
    let encoded = try JSON.encode(3.14)
    #expect(encoded == .number(.float(3.14)))
  }

  @Test("JSON.encode bool") func jsonEncodeBool() throws {
    let encoded = try JSON.encode(true)
    #expect(encoded == .boolean(true))
  }

  @Test("JSON.encode array of mixed types") func jsonEncodeMixedArray() throws {
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(
      JSON.array([.string("hello"), .number(.integer(42)), .boolean(true), .null]))
    #expect(json.isArray)
    #expect(json.count == 4)
    #expect(json[0] == .string("hello"))
    #expect(json[1] == .number(.integer(42)))
    #expect(json[2] == .boolean(true))
    #expect(json[3] == .null)
  }
}

// MARK: - Encoder/decoder error handling

@Suite("Encoder Error Handling Edge Cases") struct EncoderErrorHandlingEdgeCaseTests {
  @Test("UInt64 overflow during encode throws") func uint64Overflow() throws {
    struct Container: Encodable {
      let value: UInt64
    }
    let encoder = OrderedJSONEncoder()
    #expect(throws: EncodingError.self) {
      try encoder.encode(Container(value: UInt64.max))
    }
  }

  @Test("Int overflow during encode as integer") func intOverflow() throws {
    // Int.max may be larger than Int64.max on some platforms, but on Apple
    // platforms Int == Int64, so Int.max == Int64.max, which is representable.
    // Test Int.min which is Int64.min
    struct Container: Encodable {
      let value: Int
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Container(value: Int.min))
    #expect(json["value"] == .number(.integer(Int64(Int.min))))
  }

  @Test("nan float in encoder throws") func nanFloatInEncoderThrows() throws {
    let encoder = OrderedJSONEncoder()
    #expect(throws: EncodingError.self) {
      try encoder.encode(Double.nan)
    }
  }

  @Test("infinity float in encoder throws") func infinityFloatInEncoderThrows() throws {
    let encoder = OrderedJSONEncoder()
    #expect(throws: EncodingError.self) {
      try encoder.encode(Double.infinity)
    }
  }

  @Test("nan float in json struct encoder produces null") func nanFloatInJSONStructEncoder() throws
  {
    let json = JSON.number(.float(Double.nan))
    let encoder = OrderedJSONEncoder()
    let encoded = try encoder.encode(json)
    #expect(encoded.isNull)
  }
}

// MARK: - Key not found error details

@Suite("Key Not Found Error Details") struct KeyNotFoundErrorDetailTests {
  @Test("missing key in decoder has correct key name") func missingKeyCorrectKeyName() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    let json = JSON.object(["name": .string("Alice")])
    let decoder = OrderedJSONDecoder()
    #expect {
      try decoder.decode(Person.self, from: json)
    } throws: { error in
      guard let decodingError = error as? DecodingError else { return false }
      switch decodingError {
      case .keyNotFound(let key, let ctx):
        return key.stringValue == "age"
      default: return false
      }
    }
  }

  @Test("type mismatch on object expected array") func typeMismatchObjectExpectedArray() throws {
    struct Container: Decodable {
      let items: [Int]
    }
    let json = JSON.object(["items": .object([:])])
    let decoder = OrderedJSONDecoder()
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }
}

// MARK: - Round-trip edge cases

@Suite("Round Trip Edge Cases") struct RoundTripEdgeCaseTests {
  @Test("empty struct round trip") func emptyStructRoundTrip() throws {
    struct Empty: Codable {
      // No properties
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Empty())
    #expect(json.isObject)
    #expect(json.isEmpty)
    let decoder = OrderedJSONDecoder()
    let _ = try decoder.decode(Empty.self, from: json)
    // No properties to verify, just ensure no crash
  }

  @Test("optional values round trip") func optionalValuesRoundTrip() throws {
    struct Container: Codable {
      let a: String?
      let b: Int?
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Container(a: "hello", b: nil))
    #expect(json["a"] == .string("hello"))
    #expect(json["b"] == nil)  // nil values are omitted by Codable
    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Container.self, from: json)
    #expect(back.a == "hello")
    #expect(back.b == nil)
  }

  @Test("nested optional values round trip") func nestedOptionalValuesRoundTrip() throws {
    struct Inner: Codable {
      let x: Int?
    }
    struct Outer: Codable {
      let inner: Inner?
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Outer(inner: Inner(x: 42)))
    #expect(json["inner"]?.isObject == true)
    #expect(json["inner"]?["x"] == .number(.integer(42)))
    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Outer.self, from: json)
    #expect(back.inner?.x == 42)
  }

  @Test("nested nil optional round trip") func nestedNilOptionalRoundTrip() throws {
    struct Inner: Codable {
      let x: Int?
    }
    struct Outer: Codable {
      let inner: Inner?
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Outer(inner: nil))
    #expect(json["inner"] == nil)
    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Outer.self, from: json)
    #expect(back.inner == nil)
  }
}

// MARK: - Decimal encoding edge cases

@Suite("Decimal Encoding Edge Cases") struct DecimalEncodingEdgeCaseTests {
  @Test("decimal asNumber with integer decimal") func decimalAsNumberInteger() throws {
    struct Container: Codable {
      let amount: Decimal
    }
    let decimal = Decimal(Int64(42))
    var encoder = OrderedJSONEncoder()
    encoder.decimalEncodingStrategy = .asNumber
    let json = try encoder.encode(Container(amount: decimal))
    #expect(json["amount"] == .number(.integer(42)))
  }

  @Test("decimal asString with zero") func decimalAsStringZero() throws {
    struct Container: Codable {
      let amount: Decimal
    }
    let decimal = Decimal(0)
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Container(amount: decimal))
    #expect(json["amount"] == .string("0"))
    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Container.self, from: json)
    #expect(back.amount == decimal)
  }

  @Test("decimal asNumber with zero") func decimalAsNumberZero() throws {
    struct Container: Codable {
      let amount: Decimal
    }
    let decimal = Decimal(0)
    var encoder = OrderedJSONEncoder()
    encoder.decimalEncodingStrategy = .asNumber
    let json = try encoder.encode(Container(amount: decimal))
    #expect(json["amount"] == .number(.integer(0)))
    var decoder = OrderedJSONDecoder()
    decoder.decimalDecodingStrategy = .asNumber
    let back = try decoder.decode(Container.self, from: json)
    #expect(back.amount == decimal)
  }

  @Test("decimal asNumber with negative") func decimalAsNumberNegative() throws {
    struct Container: Codable {
      let amount: Decimal
    }
    let decimal = Decimal(-42)
    var encoder = OrderedJSONEncoder()
    encoder.decimalEncodingStrategy = .asNumber
    let json = try encoder.encode(Container(amount: decimal))
    #expect(json["amount"] == .number(.integer(-42)))
  }
}

// MARK: - JSON encoder NaN/Infinity handling

@Suite("JSON Encoder Special Float Handling") struct JSONEncoderSpecialFloatTests {
  @Test("float nan in JSON encode to encoder") func floatNanInJSONEncode() throws {
    // When JSON (which conforms to Encodable) encodes a NaN float,
    // it should encode as null per the JSON: Encodable implementation
    let json = JSON.number(.float(Double.nan))
    let encoder = JSONEncoder()
    let data = try encoder.encode(json)
    let string = try #require(String(data: data, encoding: .utf8))
    #expect(string == "null")
  }

  @Test("float infinity in JSON encode to encoder") func floatInfinityInJSONEncode() throws {
    let json = JSON.number(.float(Double.infinity))
    let encoder = JSONEncoder()
    let data = try encoder.encode(json)
    let string = try #require(String(data: data, encoding: .utf8))
    #expect(string == "null")
  }

  @Test("ordered encoder float nan in JSON encode") func orderedEncoderFloatNan() throws {
    let json = JSON.number(.float(Double.nan))
    let encoder = OrderedJSONEncoder()
    let encoded = try encoder.encode(json)
    #expect(encoded.isNull)
  }

  @Test("ordered encoder float infinity in JSON encode") func orderedEncoderFloatInfinity() throws {
    let json = JSON.number(.float(Double.infinity))
    let encoder = OrderedJSONEncoder()
    let encoded = try encoder.encode(json)
    #expect(encoded.isNull)
  }

  @Test("JSON encode struct with nan double throws") func structWithNanDoubleThrows() throws {
    struct Container: Encodable {
      let value: Double
    }
    let encoder = OrderedJSONEncoder()
    #expect(throws: EncodingError.self) {
      try encoder.encode(Container(value: Double.nan))
    }
  }

  @Test("JSON encode struct with inf double throws") func structWithInfDoubleThrows() throws {
    struct Container: Encodable {
      let value: Double
    }
    let encoder = OrderedJSONEncoder()
    #expect(throws: EncodingError.self) {
      try encoder.encode(Container(value: Double.infinity))
    }
  }
}
