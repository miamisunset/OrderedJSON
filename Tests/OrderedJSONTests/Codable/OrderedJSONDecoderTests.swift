import Foundation
import Testing

@testable import OrderedJSON

@Suite("OrderedJSONDecoder Tests") struct OrderedJSONDecoderTests {
  @Test("ordered decoder from json") func orderedDecoderFromJSON() throws {
    let json = JSON.object([
      "name": .string("Alice"),
      "age": .number(.integer(30)),
    ])
    let decoder = OrderedJSONDecoder()
    let decoded: JSON = try decoder.decode(JSON.self, from: json)
    #expect(decoded == json)
  }

  @Test("ordered decoder from data") func orderedDecoderFromData() throws {
    let jsonString = #"{"name": "Bob", "age": 25}"#
    let data = Data(jsonString.utf8)
    let decoder = OrderedJSONDecoder()
    let decoded: JSON = try decoder.decode(JSON.self, from: data)
    #expect(decoded["name"] == .string("Bob"))
    #expect(decoded["age"] == .number(.integer(25)))
  }

  @Test("ordered decoder from string") func orderedDecoderFromString() throws {
    let decoder = OrderedJSONDecoder()
    let decoded: JSON = try decoder.decode(JSON.self, from: #"{"x": 1}"#)
    #expect(decoded["x"] == .number(.integer(1)))
  }

  @Test("ordered decoder preserves key order") func orderedDecoderPreservesKeyOrder() throws {
    let jsonString = #"{"z": 1, "a": 2, "m": 3}"#
    let decoder = OrderedJSONDecoder()
    let decoded: JSON = try decoder.decode(JSON.self, from: jsonString)
    let keys = decoded.keys
    #expect(keys?[0] == "z")
    #expect(keys?[1] == "a")
    #expect(keys?[2] == "m")
  }

  @Test("ordered decoder struct") func orderedDecoderStruct() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    let jsonString = #"{"name": "Alice", "age": 30}"#
    let decoder = OrderedJSONDecoder()
    let person = try decoder.decode(Person.self, from: jsonString)
    #expect(person.name == "Alice")
    #expect(person.age == 30)
  }
}
