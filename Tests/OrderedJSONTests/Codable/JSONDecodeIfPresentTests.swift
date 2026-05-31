import Testing

@testable import OrderedJSON

@Suite("Decode If Present Tests") struct JSONDecodeIfPresentTests {
  @Test("decode if present present") func decodeIfPresentPresent() throws {
    struct Person: Decodable {
      let name: String
      let age: Int?
    }
    let json = #"{"name": "Alice", "age": 30}"#
    let decoder = OrderedJSONDecoder()
    let person = try decoder.decode(Person.self, from: json)
    #expect(person.name == "Alice")
    #expect(person.age == 30)
  }

  @Test("decode if present missing") func decodeIfPresentMissing() throws {
    struct Person: Decodable {
      let name: String
      let age: Int?
    }
    let json = #"{"name": "Alice"}"#
    let decoder = OrderedJSONDecoder()
    let person = try decoder.decode(Person.self, from: json)
    #expect(person.name == "Alice")
    #expect(person.age == nil)
  }

  @Test("decode if present explicit null") func decodeIfPresentExplicitNull() throws {
    struct Person: Decodable {
      let name: String
      let age: Int?
    }
    let json = #"{"name": "Alice", "age": null}"#
    let decoder = OrderedJSONDecoder()
    let person = try decoder.decode(Person.self, from: json)
    #expect(person.name == "Alice")
    #expect(person.age == nil)
  }

  @Test("decode if present missing with extras") func decodeIfPresentMissingWithExtras() throws {
    struct Person: Decodable {
      let name: String
      let age: Int?
    }
    let json = #"{"name": "Alice", "color": "blue"}"#
    let decoder = OrderedJSONDecoder()
    let wrapped = try decoder.decode(JSONWithUnknownKeys<Person>.self, from: json)
    #expect(wrapped.value.name == "Alice")
    #expect(wrapped.value.age == nil)
    #expect(wrapped.unknownKeys["color"] == .string("blue"))
  }
}
