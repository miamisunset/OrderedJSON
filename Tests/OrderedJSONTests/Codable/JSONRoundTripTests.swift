import Foundation
import Testing

@testable import OrderedJSON

@Suite("Round Trip Tests") struct JSONRoundTripTests {
  @Test("ordered json encoder decoder round trip") func orderedJSONEncoderDecoderRoundTrip() throws
  {
    struct Person: Codable {
      let name: String
      let age: Int
    }
    let original = Person(name: "Alice", age: 30)
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(original)
    let jsonString = json.dump(indent: .compact)
    let parsed = try JSON.parse(jsonString)
    let decoder = OrderedJSONDecoder()
    let roundTripped = try decoder.decode(Person.self, from: parsed)
    #expect(roundTripped.name == "Alice")
    #expect(roundTripped.age == 30)
  }

  @Test("ordered json encoder decoder array round trip")
  func orderedJSONEncoderDecoderArrayRoundTrip() throws {
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode([1, 2, 3])
    let jsonString = json.dump(indent: .compact)
    let parsed = try JSON.parse(jsonString)
    let decoder = OrderedJSONDecoder()
    let arr = try decoder.decode([Int].self, from: parsed)
    #expect(arr == [1, 2, 3])
  }

  @Test("ordered json encoder decoder nested round trip")
  func orderedJSONEncoderDecoderNestedRoundTrip() throws {
    struct Address: Codable {
      let city: String
      let zip: String
    }
    struct Person: Codable {
      let name: String
      let address: Address
    }
    let original = Person(
      name: "Alice",
      address: Address(city: "NYC", zip: "10001")
    )
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(original)
    let jsonString = json.dump(indent: .compact)
    let parsed = try JSON.parse(jsonString)
    let decoder = OrderedJSONDecoder()
    let roundTripped = try decoder.decode(Person.self, from: parsed)
    #expect(roundTripped.name == "Alice")
    #expect(roundTripped.address.city == "NYC")
    #expect(roundTripped.address.zip == "10001")
  }
}
