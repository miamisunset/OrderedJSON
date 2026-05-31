import Foundation
import Testing

@testable import OrderedJSON

@Suite("Optional Date Tests") struct JSONOptionalDateTests {
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
