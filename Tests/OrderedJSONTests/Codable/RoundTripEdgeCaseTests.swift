import Foundation
import Testing

@testable import OrderedJSON

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
