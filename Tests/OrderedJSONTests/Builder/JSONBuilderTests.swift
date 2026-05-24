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

  let keys = json.objectKeys
  #expect(keys?[0] == "z")
  #expect(keys?[1] == "a")
  #expect(keys?[2] == "m")
}

@Test func objectBuilderNestedObject() throws {
  let json = JSON.ObjectBuilder()
    .set("name", "Alice")
    .set("address", JSON.ObjectBuilder()
      .set("city", "NYC")
      .set("zip", "10001"))
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
      .add("user"))
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

@Test func objectBuilderRemoveNonExistent() throws {
  let json = JSON.ObjectBuilder()
    .set("a", 1)
    .remove("nonexistent")
    .build()

  #expect(json.count == 1)
  #expect(json["a"] == .number(.integer(1)))
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

@Test func objectBuilderBuildStringWithIndent() throws {
  let str = JSON.ObjectBuilder()
    .set("x", 1)
    .set("y", "hello")
    .buildString(indent: 2)

  let expected = """
{
  "x": 1,
  "y": "hello"
}
"""
  #expect(str == expected)
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

@Test func objectBuilderUInt() throws {
  let json = JSON.ObjectBuilder()
    .set("small", UInt(42))
    .set("large", UInt(Int64.max))
    .build()

  #expect(json["small"] == .number(.integer(42)))
  #expect(json["large"] == .number(.integer(Int64.max)))
}

@Test func objectBuilderUInt64Overflow() throws {
  let big = UInt64(Int64.max) + 1
  let json = JSON.ObjectBuilder()
    .set("overflow", big)
    .build()

  // Values > Int64.max are stored as float
  #expect(json["overflow"]?.isFloat == true)
  #expect(json["overflow"] == .number(.float(Double(big))))
}

@Test func objectBuilderSetNull() throws {
  let json = JSON.ObjectBuilder()
    .set("a", 1)
    .setNull("b")
    .build()

  #expect(json["b"] == .null)
}

@Test func objectBuilderSetIfPresent() throws {
  let json = JSON.ObjectBuilder()
    .set("a", 1)
    .setIfPresent("b", "hello" as String?)
    .setIfPresent("c", nil as String?)
    .build()

  #expect(json.count == 2)
  #expect(json["b"] == .string("hello"))
  #expect(json["c"] == nil)
}

@Test func objectBuilderSetIfPresentBool() throws {
  let json = JSON.ObjectBuilder()
    .setIfPresent("active", true as Bool?)
    .setIfPresent("missing", nil as Bool?)
    .build()

  #expect(json.count == 1)
  #expect(json["active"] == .boolean(true))
}

@Test func objectBuilderSetIfPresentInt() throws {
  let json = JSON.ObjectBuilder()
    .setIfPresent("val", 42 as Int?)
    .setIfPresent("nil", nil as Int?)
    .build()

  #expect(json.count == 1)
  #expect(json["val"] == .number(.integer(42)))
}

@Test func objectBuilderSetIfPresentDouble() throws {
  let json = JSON.ObjectBuilder()
    .setIfPresent("val", 3.14 as Double?)
    .setIfPresent("nil", nil as Double?)
    .build()

  #expect(json.count == 1)
  #expect(json["val"] == .number(.float(3.14)))
}

@Test func objectBuilderSetIfPresentFloat() throws {
  let json = JSON.ObjectBuilder()
    .setIfPresent("val", Float(1.5) as Float?)
    .setIfPresent("nil", nil as Float?)
    .build()

  #expect(json.count == 1)
  #expect(json["val"]?.isFloat == true)
}

@Test func objectBuilderSetIfPresentUInt() throws {
  let json = JSON.ObjectBuilder()
    .setIfPresent("small", UInt?(42))
    .setIfPresent("nil", nil as UInt?)
    .build()

  #expect(json.count == 1)
  #expect(json["small"] == .number(.integer(42)))
}

@Test func objectBuilderSetIfPresentJSON() throws {
  let json = JSON.ObjectBuilder()
    .set("a", 1)
    .setIfPresent("b", JSON?(.string("hello")))
    .setIfPresent("c", nil as JSON?)
    .build()

  #expect(json.count == 2)
  #expect(json["b"] == .string("hello"))
}

@Test func objectBuilderSetIfPresentJSONArray() throws {
  let json = JSON.ObjectBuilder()
    .setIfPresent("items", [JSON]?([.string("a"), .number(.integer(1))]))
    .setIfPresent("nil", nil as [JSON]?)
    .build()

  #expect(json.count == 1)
  #expect(json["items"]?.isArray == true)
  #expect(json["items"]?[0] == .string("a"))
}

@Test func objectBuilderSetIfPresentObjectBuilder() throws {
  let json = JSON.ObjectBuilder()
    .set("a", 1)
    .setIfPresent("addr", JSON.ObjectBuilder?(JSON.ObjectBuilder()
      .set("city", "NYC")))
    .setIfPresent("nil", nil as JSON.ObjectBuilder?)
    .build()

  #expect(json.count == 2)
  #expect(json["addr"]?.isObject == true)
  #expect(json["addr"]?["city"] == .string("NYC"))
}

@Test func objectBuilderSetIfPresentArrayBuilder() throws {
  let json = JSON.ObjectBuilder()
    .set("a", 1)
    .setIfPresent("tags", JSON.ArrayBuilder?(JSON.ArrayBuilder()
      .add("x")
      .add("y")))
    .setIfPresent("nil", nil as JSON.ArrayBuilder?)
    .build()

  #expect(json.count == 2)
  #expect(json["tags"]?.isArray == true)
  #expect(json["tags"]?[0] == .string("x"))
}

@Test func objectBuilderMerge() throws {
  let merged = JSON.ObjectBuilder()
    .set("a", 1)
    .set("b", 2)
    .merge(JSON.ObjectBuilder()
      .set("c", 3)
      .set("d", 4))
    .build()

  #expect(merged.count == 4)
  #expect(merged["a"] == .number(.integer(1)))
  #expect(merged["b"] == .number(.integer(2)))
  #expect(merged["c"] == .number(.integer(3)))
  #expect(merged["d"] == .number(.integer(4)))
}

@Test func objectBuilderMergeOverwrites() throws {
  let merged = JSON.ObjectBuilder()
    .set("a", 1)
    .set("b", 2)
    .merge(JSON.ObjectBuilder()
      .set("b", 99)
      .set("c", 3))
    .build()

  #expect(merged.count == 3)
  #expect(merged["a"] == .number(.integer(1)))
  #expect(merged["b"] == .number(.integer(99)))
  #expect(merged["c"] == .number(.integer(3)))
}

@Test func objectBuilderMergeKeyOrder() throws {
  let merged = JSON.ObjectBuilder()
    .set("a", 1)
    .set("b", 2)
    .merge(JSON.ObjectBuilder()
      .set("b", 99)  // overwrite — keeps original position
      .set("c", 3))   // new — appended at end
    .build()

  let keys = merged.objectKeys
  #expect(keys?[0] == "a")
  #expect(keys?[1] == "b")  // "b" kept original position even though value changed
  #expect(keys?[2] == "c")  // "c" appended at end
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
      .set("y", 2))
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
      .add(99))
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

@Test func arrayBuilderBuildStringWithIndent() throws {
  let str = JSON.ArrayBuilder()
    .add(1)
    .add("two")
    .buildString(indent: 2)

  let expected = """
[
  1,
  "two"
]
"""
  #expect(str == expected)
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

@Test func arrayBuilderUInt() throws {
  let json = JSON.ArrayBuilder()
    .add(UInt(42))
    .add(UInt(Int64.max))
    .build()

  #expect(json[0] == .number(.integer(42)))
  #expect(json[1] == .number(.integer(Int64.max)))
}

@Test func arrayBuilderUInt64Overflow() throws {
  let big = UInt64(Int64.max) + 1
  let json = JSON.ArrayBuilder()
    .add(big)
    .build()

  #expect(json[0]?.isFloat == true)
  #expect(json[0] == .number(.float(Double(big))))
}

@Test func arrayBuilderAddNull() throws {
  let json = JSON.ArrayBuilder()
    .add("a")
    .addNull()
    .build()

  #expect(json[1] == .null)
}

@Test func arrayBuilderAppendContentsOfBuilder() throws {
  let combined = JSON.ArrayBuilder()
    .add("a")
    .add("b")
    .append(contentsOf: JSON.ArrayBuilder()
      .add("c")
      .add("d"))
    .build()

  #expect(combined.count == 4)
  #expect(combined[0] == .string("a"))
  #expect(combined[1] == .string("b"))
  #expect(combined[2] == .string("c"))
  #expect(combined[3] == .string("d"))
}

@Test func arrayBuilderAppendContentsOfArray() throws {
  let combined = JSON.ArrayBuilder()
    .add(1)
    .add(2)
    .append(contentsOf: [.string("x"), .number(.integer(3))])
    .build()

  #expect(combined.count == 4)
  #expect(combined[0] == .number(.integer(1)))
  #expect(combined[1] == .number(.integer(2)))
  #expect(combined[2] == .string("x"))
  #expect(combined[3] == .number(.integer(3)))
}

@Test func arrayBuilderAddIfPresent() throws {
  let json = JSON.ArrayBuilder()
    .add("a")
    .addIfPresent("hello" as String?)
    .addIfPresent(nil as String?)
    .addIfPresent(42 as Int?)
    .addIfPresent(nil as Int?)
    .addIfPresent(true as Bool?)
    .addIfPresent(nil as Bool?)
    .build()

  #expect(json.count == 3)
  #expect(json[0] == .string("a"))
  #expect(json[1] == .string("hello"))
  #expect(json[2] == .boolean(true))
}

@Test func arrayBuilderAddIfPresentUInt() throws {
  let json = JSON.ArrayBuilder()
    .addIfPresent(UInt?(42))
    .addIfPresent(nil as UInt?)
    .build()

  #expect(json.count == 1)
  #expect(json[0] == .number(.integer(42)))
}

@Test func arrayBuilderAddIfPresentJSON() throws {
  let json = JSON.ArrayBuilder()
    .add("a")
    .addIfPresent(JSON?(.string("hello")))
    .addIfPresent(nil as JSON?)
    .build()

  #expect(json.count == 2)
  #expect(json[1] == .string("hello"))
}

@Test func arrayBuilderAddIfPresentObjectBuilder() throws {
  let json = JSON.ArrayBuilder()
    .add("a")
    .addIfPresent(JSON.ObjectBuilder?(JSON.ObjectBuilder()
      .set("x", 1)))
    .addIfPresent(nil as JSON.ObjectBuilder?)
    .build()

  #expect(json.count == 2)
  #expect(json[1]?.isObject == true)
  #expect(json[1]?["x"] == .number(.integer(1)))
}

@Test func arrayBuilderAddIfPresentArrayBuilder() throws {
  let json = JSON.ArrayBuilder()
    .add("a")
    .addIfPresent(JSON.ArrayBuilder?(JSON.ArrayBuilder()
      .add("inner")))
    .addIfPresent(nil as JSON.ArrayBuilder?)
    .build()

  #expect(json.count == 2)
  #expect(json[1]?.isArray == true)
  #expect(json[1]?[0] == .string("inner"))
}

@Test func arrayBuilderAddIfPresentDouble() throws {
  let json = JSON.ArrayBuilder()
    .addIfPresent(3.14 as Double?)
    .addIfPresent(nil as Double?)
    .build()

  #expect(json.count == 1)
  #expect(json[0] == .number(.float(3.14)))
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
      .add("user"))
    .build()

  let decoder = OrderedJSONDecoder()
  let person = try decoder.decode(Person.self, from: json)
  #expect(person.name == "Alice")
  #expect(person.age == 30)
  #expect(person.tags == ["admin", "user"])
}
