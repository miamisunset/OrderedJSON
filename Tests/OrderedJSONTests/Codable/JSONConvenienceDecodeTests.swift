import Foundation
import Testing

@testable import OrderedJSON

@Suite("Convenience Decode Tests") struct JSONConvenienceDecodeTests {
  @Test("convenience decode from string") func convenienceDecodeFromString() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    let person = try JSON.decode(Person.self, from: "{\"name\": \"Alice\", \"age\": 30}")
    #expect(person.name == "Alice")
    #expect(person.age == 30)
  }

  @Test("convenience decode from data") func convenienceDecodeFromData() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    let data = Data("{\"name\": \"Bob\", \"age\": 25}".utf8)
    let person = try JSON.decode(Person.self, from: data)
    #expect(person.name == "Bob")
    #expect(person.age == 25)
  }

  @Test("convenience decode json") func convenienceDecodeJSON() throws {
    let json: JSON = try JSON.decode(JSON.self, from: "{\"x\": 1, \"y\": 2}")
    #expect(json["x"] == .number(.integer(1)))
    #expect(json["y"] == .number(.integer(2)))
  }
}
