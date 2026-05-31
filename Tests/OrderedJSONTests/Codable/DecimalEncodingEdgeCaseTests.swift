import Foundation
import Testing

@testable import OrderedJSON

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
