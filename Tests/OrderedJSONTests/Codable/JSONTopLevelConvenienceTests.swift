import OrderedCollections
import Testing

@testable import OrderedJSON

@Suite("Top Level Convenience Tests") struct JSONTopLevelConvenienceTests {
  @Test("top level encode struct") func topLevelEncodeStruct() throws {
    struct Person: Encodable {
      let name: String
      let age: Int
    }
    let person = Person(name: "Alice", age: 30)
    let json = try JSON.encode(person)
    #expect(json.isObject)
    #expect(json["name"] == .string("Alice"))
    #expect(json["age"] == .number(.integer(30)))
  }

  @Test("top level encode array") func topLevelEncodeArray() throws {
    let json = try JSON.encode([1, 2, 3])
    #expect(json.isArray)
    #expect(json.count == 3)
    #expect(json[0] == .number(.integer(1)))
    #expect(json[1] == .number(.integer(2)))
    #expect(json[2] == .number(.integer(3)))
  }

  @Test("top level encode string") func topLevelEncodeString() throws {
    let json = try JSON.encode("hello")
    #expect(json.isString)
    #expect(json == .string("hello"))
  }

  @Test("top level decode from json") func topLevelDecodeFromJSON() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    let json = JSON.object([
      "name": .string("Bob"),
      "age": .number(.integer(25)),
    ])
    let person = try JSON.decode(Person.self, from: json)
    #expect(person.name == "Bob")
    #expect(person.age == 25)
  }

  @Test("top level decode json type") func topLevelDecodeJSONType() throws {
    let json = JSON.object(["x": .number(.integer(1)), "y": .number(.integer(2))])
    let decoded: JSON = try JSON.decode(JSON.self, from: json)
    #expect(decoded["x"] == .number(.integer(1)))
    #expect(decoded["y"] == .number(.integer(2)))
  }

  @Test("top level encode decode round trip") func topLevelEncodeDecodeRoundTrip() throws {
    struct Person: Codable {
      let name: String
      let age: Int
    }
    let original = Person(name: "Alice", age: 30)
    let encoded = try JSON.encode(original)
    let decoded = try JSON.decode(Person.self, from: encoded)
    #expect(decoded.name == "Alice")
    #expect(decoded.age == 30)
  }

  @Test("top level encode preserves key order") func topLevelEncodePreservesKeyOrder() throws {
    struct Ordered: Encodable {
      let z: Int
      let a: Int
      let m: Int
    }
    let json = try JSON.encode(Ordered(z: 1, a: 2, m: 3))
    #expect(json.isObject)
    #expect(json.count == 3)
    let keys = json.keys
    #expect(keys?[0] == "z")
    #expect(keys?[1] == "a")
    #expect(keys?[2] == "m")
  }
}
