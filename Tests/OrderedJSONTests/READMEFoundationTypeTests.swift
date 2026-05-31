import Foundation
import Testing

@testable import OrderedJSON

@Test func readmeDateStrategies() throws {
  struct Event: Codable {
    let timestamp: Date
  }

  let event = Event(timestamp: Date(timeIntervalSince1970: 1_234_567_890))

  // Seconds since 1970
  var encoder = OrderedJSONEncoder()
  encoder.dateEncodingStrategy = .secondsSince1970
  let json = try encoder.encode(event)
  #expect(json["timestamp"]?.isNumber == true)

  var decoder = OrderedJSONDecoder()
  decoder.dateDecodingStrategy = .secondsSince1970
  let back = try decoder.decode(Event.self, from: json)
  #expect(Int64(back.timestamp.timeIntervalSince1970) == 1_234_567_890)

  // ISO 8601
  encoder.dateEncodingStrategy = .iso8601
  decoder.dateDecodingStrategy = .iso8601

  // Custom date formatter
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd"
  encoder.dateEncodingStrategy = .formatted(formatter)
  decoder.dateDecodingStrategy = .formatted(formatter)

  // Milliseconds since 1970
  encoder.dateEncodingStrategy = .millisecondsSince1970
  decoder.dateDecodingStrategy = .millisecondsSince1970

  // Custom closure
  encoder.dateEncodingStrategy = .custom { date, encoder in
    return .object(["epoch": .number(.integer(Int64(date.timeIntervalSince1970)))])
  }
  decoder.dateDecodingStrategy = .custom { json, decoder in
    return Date(timeIntervalSince1970: try json["epoch"]?.requireDouble() ?? 0)
  }
}

@Test func readmeDataStrategies() throws {
  struct Container: Codable {
    let data: Data
  }

  let raw = Data([0xDE, 0xAD, 0xBE, 0xEF])

  var encoder = OrderedJSONEncoder()
  encoder.dataEncodingStrategy = .base64
  let json = try encoder.encode(Container(data: raw))

  var decoder = OrderedJSONDecoder()
  decoder.dataDecodingStrategy = .base64
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.data == raw)
}

@Test func readmeURLUUIDDecimal() throws {
  struct Document: Codable {
    let url: URL
    let id: UUID
    let price: Decimal
  }

  let doc = Document(
    url: URL(string: "https://example.com")!,
    id: UUID(),
    price: Decimal(string: "19.99")!
  )

  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(doc)

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Document.self, from: json)
  #expect(back.url == doc.url)
  #expect(back.id == doc.id)
  #expect(back.price == doc.price)
}
