import Foundation
import Testing

@testable import OrderedJSON

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
