import Foundation
import Testing

@testable import OrderedJSON

@Test func readmeJSONCodable() throws {
  let json = JSON.object([
    "name": .string("Alice"),
    "age": .number(.integer(30)),
  ])

  let data = try JSONEncoder().encode(json)
  let decoded = try JSONDecoder().decode(JSON.self, from: data)
  #expect(decoded["name"] == .string("Alice"))
}

@Test func readmeOrderedJSONEncoder() throws {
  struct Person: Codable {
    let name: String
    let age: Int
  }

  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Person(name: "Alice", age: 30))
  #expect(json["name"] == .string("Alice"))
  #expect(json["age"] == .number(.integer(30)))

  let string = try encoder.encodeAsString(Person(name: "Bob", age: 25))
  #expect(string == "{\"name\":\"Bob\",\"age\":25}")
}

@Test func readmeOrderedJSONDecoder() throws {
  struct Person: Decodable {
    let name: String
    let age: Int
  }

  let decoder = OrderedJSONDecoder()

  // Decode from JSON value
  let json = try JSON.parse(#"{"name": "Alice", "age": 30}"#)
  let person1 = try decoder.decode(Person.self, from: json)
  #expect(person1.name == "Alice")

  // Decode from raw data
  let data = Data(#"{"name": "Bob", "age": 25}"#.utf8)
  let person2 = try decoder.decode(Person.self, from: data)
  #expect(person2.name == "Bob")

  // Decode from JSON string
  let person3 = try decoder.decode(Person.self, from: "{\"name\": \"Charlie\", \"age\": 35}")
  #expect(person3.name == "Charlie")

  // Decode JSON itself
  let ordered = try decoder.decode(JSON.self, from: #"{"z": 1, "a": 2, "m": 3}"#)
  #expect(ordered["z"] == .number(.integer(1)))
}

@Test func readmeJSONEncodeConvenience() throws {
  struct Person: Codable {
    let name: String
    let age: Int
  }

  let json = try JSON.encode(Person(name: "Alice", age: 30))
  #expect(json["name"] == .string("Alice"))
  #expect(json["age"] == .number(.integer(30)))

  let arr = try JSON.encode([1, 2, 3])
  #expect(arr.isArray)

  let str = try JSON.encode("hello")
  #expect(str.isString)
}

@Test func readmeJSONDecodeConvenience() throws {
  struct Person: Codable {
    let name: String
    let age: Int
  }

  // From existing JSON value
  let json = JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])
  let p1 = try JSON.decode(Person.self, from: json)
  #expect(p1.name == "Alice")

  // From JSON string
  let p2 = try JSON.decode(Person.self, from: "{\"name\": \"Bob\", \"age\": 25}")
  #expect(p2.name == "Bob")

  // From raw data
  let data = Data(#"{"name": "Charlie", "age": 35}"#.utf8)
  let p3 = try JSON.decode(Person.self, from: data)
  #expect(p3.name == "Charlie")

  // With parser options
  let opts = JSON.ParserOptions(allowTrailingCommas: true)
  let p4 = try JSON.decode(Person.self, from: "{\"name\": \"Dave\", \"age\": 45,}", options: opts)
  #expect(p4.name == "Dave")
}

@Test func readmeJSONWithUnknownKeys() throws {
  struct Person: Codable {
    let name: String
    let age: Int
  }

  let data = Data(
    #"""
    {"name": "Alice", "age": 30, "color": "blue", "city": "NYC"}
    """#.utf8)

  let wrapped = try OrderedJSONDecoder().decode(
    JSONWithUnknownKeys<Person>.self, from: data)

  #expect(wrapped.value.name == "Alice")
  #expect(wrapped.value.age == 30)
  #expect(wrapped.unknownKeys["color"] == .string("blue"))
  #expect(wrapped.unknownKeys["city"] == .string("NYC"))
}

@Test func readmeThrowingAccessors() throws {
  let json = try JSON.parse(#"{"name": "Alice", "count": 42, "rate": 3.14, "active": true}"#)

  let name = try json["name"]?.requireString()
  #expect(name == "Alice")

  let active = try json["active"]?.requireBool()
  #expect(active == true)

  let count = try json["count"]?.requireInt64()
  #expect(count == 42)

  let rate = try json["rate"]?.requireDouble()
  #expect(rate == 3.14)

  let count32 = try json["count"]?.requireInt32()
  #expect(count32 == 42)
}

@Test func readmeOptionalValueAccessors() throws {
  let json = try JSON.parse(#"{"name": "Alice", "count": 42, "pi": 3.14, "ok": true}"#)

  #expect(json["name"]?.stringValue == "Alice")
  #expect(json["count"]?.intValue == 42)
  #expect(json["pi"]?.doubleValue == 3.14)
  #expect(json["ok"]?.boolValue == true)
  #expect(json["count"]?.numberValue == .integer(42))

  // Integer widened to double
  #expect(json["count"]?.doubleValue == 42.0)
}

@Test func readmeRoundTrip() throws {
  struct Person: Codable {
    let name: String
    let age: Int
    let address: String?
  }

  let original = Person(name: "Alice", age: 30, address: nil)

  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(original)

  let jsonString = json.dump()
  #expect(jsonString == "{\"name\":\"Alice\",\"age\":30}")

  let parsed = try JSON.parse(jsonString)

  let decoder = OrderedJSONDecoder()
  let roundTripped = try decoder.decode(Person.self, from: parsed)
  #expect(roundTripped.name == original.name)
  #expect(roundTripped.age == original.age)
  #expect(roundTripped.address == original.address)
}
