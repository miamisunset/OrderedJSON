import Foundation
import Testing

@testable import OrderedJSON

@Suite("Strategy Propagation Tests") struct JSONStrategyPropagationTests {
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
