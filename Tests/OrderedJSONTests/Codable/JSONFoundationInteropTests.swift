import Foundation
import Testing

@testable import OrderedJSON

@Suite("Foundation Interop Tests") struct JSONFoundationInteropTests {
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

  @Test("foundation date milliseconds since 1970") func foundationDateMillisecondsSince1970() throws
  {
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

  @Test("foundation decimal as number huge throws") func foundationDecimalAsNumberHugeThrows()
    throws
  {
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
