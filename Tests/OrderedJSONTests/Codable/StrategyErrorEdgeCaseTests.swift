import Foundation
import Testing

@testable import OrderedJSON

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
