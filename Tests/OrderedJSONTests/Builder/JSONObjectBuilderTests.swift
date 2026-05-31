import Testing

@testable import OrderedJSON

@Suite("Object Builder Tests") struct JSONObjectBuilderTests {

  @Test("object builder simple values") func objectBuilderSimpleValues() {
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

  @Test("object builder key order") func objectBuilderKeyOrder() {
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

  @Test("object builder nested object") func objectBuilderNestedObject() {
    let json = JSON.ObjectBuilder()
      .set("name", "Alice")
      .set(
        "address",
        JSON.ObjectBuilder()
          .set("city", "NYC")
          .set("zip", "10001")
      )
      .build()

    #expect(json["name"] == .string("Alice"))
    #expect(json["address"]?.isObject == true)
    #expect(json["address"]?["city"] == .string("NYC"))
    #expect(json["address"]?["zip"] == .string("10001"))
  }

  @Test("object builder nested array") func objectBuilderNestedArray() {
    let json = JSON.ObjectBuilder()
      .set(
        "tags",
        JSON.ArrayBuilder()
          .add("admin")
          .add("user")
      )
      .build()

    #expect(json["tags"]?.isArray == true)
    #expect(json["tags"]?.count == 2)
    #expect(json["tags"]?[0] == .string("admin"))
    #expect(json["tags"]?[1] == .string("user"))
  }

  @Test("object builder explicit json") func objectBuilderExplicitJSON() {
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

  @Test("object builder remove") func objectBuilderRemove() {
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

  @Test("object builder remove non existent") func objectBuilderRemoveNonExistent() {
    let json = JSON.ObjectBuilder()
      .set("a", 1)
      .remove("nonexistent")
      .build()

    #expect(json.count == 1)
    #expect(json["a"] == .number(.integer(1)))
  }

  @Test("object builder count") func objectBuilderCount() {
    let builder = JSON.ObjectBuilder()
    #expect(builder.count == 0)

    builder.set("a", 1).set("b", 2)
    #expect(builder.count == 2)
  }

  @Test("object builder build string") func objectBuilderBuildString() {
    let str = JSON.ObjectBuilder()
      .set("x", 1)
      .set("y", "hello")
      .buildString()

    #expect(str == #"{"x":1,"y":"hello"}"#)
  }

  @Test("object builder build string with indent") func objectBuilderBuildStringWithIndent() {
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

  @Test("object builder int64 value") func objectBuilderInt64Value() {
    let large: Int64 = 9_000_000_000_000_000_000
    let json = JSON.ObjectBuilder()
      .set("large", large)
      .build()

    #expect(json["large"] == .number(.integer(large)))
  }

  @Test("object builder float value") func objectBuilderFloatValue() {
    let json = JSON.ObjectBuilder()
      .set("temp", Float(98.6))
      .build()

    #expect(json["temp"]?.isFloat == true)
  }

  @Test("object builder array of json") func objectBuilderArrayOfJSON() {
    let json = JSON.ObjectBuilder()
      .set("items", [.string("a"), .number(.integer(1)), .boolean(true)])
      .build()

    #expect(json["items"]?.isArray == true)
    #expect(json["items"]?.count == 3)
    #expect(json["items"]?[0] == .string("a"))
    #expect(json["items"]?[1] == .number(.integer(1)))
    #expect(json["items"]?[2] == .boolean(true))
  }

  @Test("object builder uint") func objectBuilderUInt() {
    let json = JSON.ObjectBuilder()
      .set("small", UInt(42))
      .set("large", UInt(Int64.max))
      .build()

    #expect(json["small"] == .number(.integer(42)))
    #expect(json["large"] == .number(.integer(Int64.max)))
  }

  @Test("object builder uint64 overflow") func objectBuilderUInt64Overflow() {
    let big = UInt64(Int64.max) + 1
    let json = JSON.ObjectBuilder()
      .set("overflow", big)
      .build()

    // Values > Int64.max are stored as float
    #expect(json["overflow"]?.isFloat == true)
    #expect(json["overflow"] == .number(.float(Double(big))))
  }

  @Test("object builder set null") func objectBuilderSetNull() {
    let json = JSON.ObjectBuilder()
      .set("a", 1)
      .setNull("b")
      .build()

    #expect(json["b"] == .null)
  }

  @Test("object builder set if present") func objectBuilderSetIfPresent() {
    let json = JSON.ObjectBuilder()
      .set("a", 1)
      .setIfPresent("b", "hello" as String?)
      .setIfPresent("c", nil as String?)
      .build()

    #expect(json.count == 2)
    #expect(json["b"] == .string("hello"))
    #expect(json["c"] == nil)
  }

  @Test("object builder set if present bool") func objectBuilderSetIfPresentBool() {
    let json = JSON.ObjectBuilder()
      .setIfPresent("active", true as Bool?)
      .setIfPresent("missing", nil as Bool?)
      .build()

    #expect(json.count == 1)
    #expect(json["active"] == .boolean(true))
  }

  @Test("object builder set if present int") func objectBuilderSetIfPresentInt() {
    let json = JSON.ObjectBuilder()
      .setIfPresent("val", 42 as Int?)
      .setIfPresent("nil", nil as Int?)
      .build()

    #expect(json.count == 1)
    #expect(json["val"] == .number(.integer(42)))
  }

  @Test("object builder set if present double") func objectBuilderSetIfPresentDouble() {
    let json = JSON.ObjectBuilder()
      .setIfPresent("val", 3.14 as Double?)
      .setIfPresent("nil", nil as Double?)
      .build()

    #expect(json.count == 1)
    #expect(json["val"] == .number(.float(3.14)))
  }

  @Test("object builder set if present float") func objectBuilderSetIfPresentFloat() {
    let json = JSON.ObjectBuilder()
      .setIfPresent("val", Float(1.5) as Float?)
      .setIfPresent("nil", nil as Float?)
      .build()

    #expect(json.count == 1)
    #expect(json["val"]?.isFloat == true)
  }

  @Test("object builder set if present uint") func objectBuilderSetIfPresentUInt() {
    let json = JSON.ObjectBuilder()
      .setIfPresent("small", UInt?(42))
      .setIfPresent("nil", nil as UInt?)
      .build()

    #expect(json.count == 1)
    #expect(json["small"] == .number(.integer(42)))
  }

  @Test("object builder set if present json") func objectBuilderSetIfPresentJSON() {
    let json = JSON.ObjectBuilder()
      .set("a", 1)
      .setIfPresent("b", JSON?(.string("hello")))
      .setIfPresent("c", nil as JSON?)
      .build()

    #expect(json.count == 2)
    #expect(json["b"] == .string("hello"))
  }

  @Test("object builder set if present json array") func objectBuilderSetIfPresentJSONArray() {
    let json = JSON.ObjectBuilder()
      .setIfPresent("items", [JSON]?([.string("a"), .number(.integer(1))]))
      .setIfPresent("nil", nil as [JSON]?)
      .build()

    #expect(json.count == 1)
    #expect(json["items"]?.isArray == true)
    #expect(json["items"]?[0] == .string("a"))
  }

  @Test("object builder set if present object builder")
  func objectBuilderSetIfPresentObjectBuilder() {
    let json = JSON.ObjectBuilder()
      .set("a", 1)
      .setIfPresent(
        "addr",
        JSON.ObjectBuilder?(
          JSON.ObjectBuilder()
            .set("city", "NYC")
        )
      )
      .setIfPresent("nil", nil as JSON.ObjectBuilder?)
      .build()

    #expect(json.count == 2)
    #expect(json["addr"]?.isObject == true)
    #expect(json["addr"]?["city"] == .string("NYC"))
  }

  @Test("object builder set if present array builder") func objectBuilderSetIfPresentArrayBuilder()
  {
    let json = JSON.ObjectBuilder()
      .set("a", 1)
      .setIfPresent(
        "tags",
        JSON.ArrayBuilder?(
          JSON.ArrayBuilder()
            .add("x")
            .add("y")
        )
      )
      .setIfPresent("nil", nil as JSON.ArrayBuilder?)
      .build()

    #expect(json.count == 2)
    #expect(json["tags"]?.isArray == true)
    #expect(json["tags"]?[0] == .string("x"))
  }

  @Test("object builder merge") func objectBuilderMerge() {
    let merged = JSON.ObjectBuilder()
      .set("a", 1)
      .set("b", 2)
      .merge(
        JSON.ObjectBuilder()
          .set("c", 3)
          .set("d", 4)
      )
      .build()

    #expect(merged.count == 4)
    #expect(merged["a"] == .number(.integer(1)))
    #expect(merged["b"] == .number(.integer(2)))
    #expect(merged["c"] == .number(.integer(3)))
    #expect(merged["d"] == .number(.integer(4)))
  }

  @Test("object builder merge overwrites") func objectBuilderMergeOverwrites() {
    let merged = JSON.ObjectBuilder()
      .set("a", 1)
      .set("b", 2)
      .merge(
        JSON.ObjectBuilder()
          .set("b", 99)
          .set("c", 3)
      )
      .build()

    #expect(merged.count == 3)
    #expect(merged["a"] == .number(.integer(1)))
    #expect(merged["b"] == .number(.integer(99)))
    #expect(merged["c"] == .number(.integer(3)))
  }

  @Test("object builder merge key order") func objectBuilderMergeKeyOrder() {
    let merged = JSON.ObjectBuilder()
      .set("a", 1)
      .set("b", 2)
      .merge(
        JSON.ObjectBuilder()
          .set("b", 99)  // overwrite — keeps original position
          .set("c", 3)
      )  // new — appended at end
      .build()

    let keys = merged.objectKeys
    #expect(keys?[0] == "a")
    #expect(keys?[1] == "b")  // "b" kept original position even though value changed
    #expect(keys?[2] == "c")  // "c" appended at end
  }

}
