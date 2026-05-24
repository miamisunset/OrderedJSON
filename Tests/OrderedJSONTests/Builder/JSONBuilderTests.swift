import Foundation
import Testing

@testable import OrderedJSON

// MARK: - Object Builder

@Test func objectBuilderSimpleValues() throws {
  let json = JSON.ObjectBuilder()
    .set("name", "Alice")
    .set("age", 30)
    .set("active", true)
    .set("pi", 3.14)
    .build()

  #expect(json.isObject)
  #expect(json.count == 4)
  #expect(json["name"] == .string("Alice"))
  #expect(json["age"] == .number(.integer(30)))
  #expect(json["active"] == .boolean(true))
  #expect(json["pi"] == .number(.float(3.14)))
}

@Test func objectBuilderKeyOrder() throws {
  let json = JSON.ObjectBuilder()
    .set("z", "last")
    .set("a", "first")
    .set("m", "middle")
    .build()

  let keys = json.keys
  #expect(keys?[0] == "z")
  #expect(keys?[1] == "a")
  #expect(keys?[2] == "m")
}

@Test func objectBuilderNestedObject() throws {
  let json = JSON.ObjectBuilder()
    .set("name", "Alice")
    .set("address", JSON.ObjectBuilder()
      .set("city", "NYC")
      .set("zip", "10001")
      .build())
    .build()

  #expect(json["name"] == .string("Alice"))
  #expect(json["address"]?.isObject == true)
  #expect(json["address"]?["city"] == .string("NYC"))
  #expect(json["address"]?["zip"] == .string("10001"))
}

@Test func objectBuilderNestedArray() throws {
  let json = JSON.ObjectBuilder()
    .set("tags", JSON.ArrayBuilder()
      .add("admin")
      .add("user")
      .build())
    .build()

  #expect(json["tags"]?.isArray == true)
  #expect(json["tags"]?.count == 2)
  #expect(json["tags"]?[0] == .string("admin"))
  #expect(json["tags"]?[1] == .string("user"))
}

@Test func objectBuilderExplicitJSON() throws {
  let json = JSON.ObjectBuilder()
    .set("null", .null)
    .set("int", .number(.integer(42)))
    .set("float", .number(.float(1.5)))
    .set("array", .array([.string("a"), .number(.integer(1))]))
    .build()

  #expect(json["null"] == .null)
  #expect(json["int"] == .number(.integer(42)))
  #expect(json["float"] == .number(.float(1.5)))
  #expect(json["array"]?.isArray == true)
  #expect(json["array"]?[0] == .string("a"))
}

@Test func objectBuilderRemove() throws {
  let json = JSON.ObjectBuilder()
    .set("a", 1)
    .set("b", 2)
    .set("c", 3)
    .remove("b")
    .build()

  #expect(json.count == 2)
  #expect(json["a"] == .number(.integer(1)))
  #expect(json["c"] == .number(.integer(3)))
  #expect(json["b"] == nil)
}

@Test func objectBuilderCount() throws {
  let builder = JSON.ObjectBuilder()
  #expect(builder.count == 0)

  builder.set("a", 1).set("b", 2)
  #expect(builder.count == 2)
}

@Test func objectBuilderBuildString() throws {
  let str = JSON.ObjectBuilder()
    .set("x", 1)
    .set("y", "hello")
    .buildString()

  #expect(str == #"{"x":1,"y":"hello"}"#)
}

@Test func objectBuilderInt64Value() throws {
  let large: Int64 = 9_000_000_000_000_000_000
  let json = JSON.ObjectBuilder()
    .set("large", large)
    .build()

  #expect(json["large"] == .number(.integer(large)))
}

@Test func objectBuilderFloatValue() throws {
  let json = JSON.ObjectBuilder()
    .set("temp", Float(98.6))
    .build()

  #expect(json["temp"]?.isFloat == true)
}

@Test func objectBuilderArrayOfJSON() throws {
  let json = JSON.ObjectBuilder()
    .set("items", [.string("a"), .number(.integer(1)), .boolean(true)])
    .build()

  #expect(json["items"]?.isArray == true)
  #expect(json["items"]?.count == 3)
  #expect(json["items"]?[0] == .string("a"))
  #expect(json["items"]?[1] == .number(.integer(1)))
  #expect(json["items"]?[2] == .boolean(true))
}

// MARK: - Array Builder

@Test func arrayBuilderSimpleValues() throws {
  let json = JSON.ArrayBuilder()
    .add("a")
    .add(42)
    .add(true)
    .add(3.14)
    .build()

  #expect(json.isArray)
  #expect(json.count == 4)
  #expect(json[0] == .string("a"))
  #expect(json[1] == .number(.integer(42)))
  #expect(json[2] == .boolean(true))
  #expect(json[3] == .number(.float(3.14)))
}

@Test func arrayBuilderNestedObject() throws {
  let json = JSON.ArrayBuilder()
    .add("hello")
    .add(JSON.ObjectBuilder()
      .set("x", 1)
      .set("y", 2)
      .build())
    .build()

  #expect(json.count == 2)
  #expect(json[0] == .string("hello"))
  #expect(json[1]?.isObject == true)
  #expect(json[1]?["x"] == .number(.integer(1)))
  #expect(json[1]?["y"] == .number(.integer(2)))
}

@Test func arrayBuilderNestedArray() throws {
  let json = JSON.ArrayBuilder()
    .add("outer")
    .add(JSON.ArrayBuilder()
      .add("inner")
      .add(99)
      .build())
    .build()

  #expect(json.count == 2)
  #expect(json[0] == .string("outer"))
  #expect(json[1]?.isArray == true)
  #expect(json[1]?[0] == .string("inner"))
  #expect(json[1]?[1] == .number(.integer(99)))
}

@Test func arrayBuilderExplicitJSON() throws {
  let json = JSON.ArrayBuilder()
    .add(.null)
    .add(.number(.integer(42)))
    .add(.string("hello"))
    .add(.boolean(false))
    .build()

  #expect(json[0] == .null)
  #expect(json[1] == .number(.integer(42)))
  #expect(json[2] == .string("hello"))
  #expect(json[3] == .boolean(false))
}

@Test func arrayBuilderCount() throws {
  let builder = JSON.ArrayBuilder()
  #expect(builder.count == 0)

  builder.add("a").add("b").add("c")
  #expect(builder.count == 3)
}

@Test func arrayBuilderBuildString() throws {
  let str = JSON.ArrayBuilder()
    .add(1)
    .add("two")
    .add(true)
    .buildString()

  #expect(str == #"[1,"two",true]"#)
}

@Test func arrayBuilderInt64Value() throws {
  let large: Int64 = 9_000_000_000_000_000_000
  let json = JSON.ArrayBuilder()
    .add(large)
    .build()

  #expect(json[0] == .number(.integer(large)))
}

@Test func arrayBuilderFloatValue() throws {
  let json = JSON.ArrayBuilder()
    .add(Float(3.14))
    .build()

  #expect(json[0]?.isFloat == true)
}

@Test func arrayBuilderArrayOfJSON() throws {
  let json = JSON.ArrayBuilder()
    .add([.string("x"), .number(.integer(1))])
    .build()

  #expect(json[0]?.isArray == true)
  #expect(json[0]?[0] == .string("x"))
  #expect(json[0]?[1] == .number(.integer(1)))
}

// MARK: - Builder round-trip

@Test func builderRoundTripWithEncoderDecoder() throws {
  struct Person: Codable {
    let name: String
    let age: Int
    let tags: [String]
  }

  let json = JSON.ObjectBuilder()
    .set("name", "Alice")
    .set("age", 30)
    .set("tags", JSON.ArrayBuilder()
      .add("admin")
      .add("user")
      .build())
    .build()

  let decoder = OrderedJSONDecoder()
  let person = try decoder.decode(Person.self, from: json)
  #expect(person.name == "Alice")
  #expect(person.age == 30)
  #expect(person.tags == ["admin", "user"])
}

// MARK: - Helper: JSON keys

extension JSON {
  fileprivate var keys: [String]? {
    guard case .object(let dict) = storage else { return nil }
    return Array(dict.keys)
  }
}
