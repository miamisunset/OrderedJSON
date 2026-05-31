import Foundation
import Testing

@testable import OrderedJSON

@Suite("JSONWithExtras Tests") struct JSONWithExtrasTests {
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

  @Test("json with extras contains marks accessed") func jsonWithExtrasContainsMarksAccessed()
    throws
  {
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

  @Test("json with extras date strategy propagated") func jsonWithExtrasDateStrategyPropagated()
    throws
  {
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

  @Test("json with extras data strategy propagated") func jsonWithExtrasDataStrategyPropagated()
    throws
  {
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

  @Test("json with extras decimal strategy propagated")
  func jsonWithExtrasDecimalStrategyPropagated() throws {
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
