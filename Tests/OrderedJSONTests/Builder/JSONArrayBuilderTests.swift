import Testing

@testable import OrderedJSON

@Suite("Array Builder Tests") struct JSONArrayBuilderTests {

  @Test("array builder simple values") func arrayBuilderSimpleValues() {
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

  @Test("array builder nested object") func arrayBuilderNestedObject() {
    let json = JSON.ArrayBuilder()
      .add("hello")
      .add(
        JSON.ObjectBuilder()
          .set("x", 1)
          .set("y", 2)
      )
      .build()

    #expect(json.count == 2)
    #expect(json[0] == .string("hello"))
    #expect(json[1]?.isObject == true)
    #expect(json[1]?["x"] == .number(.integer(1)))
    #expect(json[1]?["y"] == .number(.integer(2)))
  }

  @Test("array builder nested array") func arrayBuilderNestedArray() {
    let json = JSON.ArrayBuilder()
      .add("outer")
      .add(
        JSON.ArrayBuilder()
          .add("inner")
          .add(99)
      )
      .build()

    #expect(json.count == 2)
    #expect(json[0] == .string("outer"))
    #expect(json[1]?.isArray == true)
    #expect(json[1]?[0] == .string("inner"))
    #expect(json[1]?[1] == .number(.integer(99)))
  }

  @Test("array builder explicit json") func arrayBuilderExplicitJSON() {
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

  @Test("array builder count") func arrayBuilderCount() {
    let builder = JSON.ArrayBuilder()
    #expect(builder.count == 0)

    builder.add("a").add("b").add("c")
    #expect(builder.count == 3)
  }

  @Test("array builder build string") func arrayBuilderBuildString() {
    let str = JSON.ArrayBuilder()
      .add(1)
      .add("two")
      .add(true)
      .buildString()

    #expect(str == #"[1,"two",true]"#)
  }

  @Test("array builder build string with indent") func arrayBuilderBuildStringWithIndent() {
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

  @Test("array builder int64 value") func arrayBuilderInt64Value() {
    let large: Int64 = 9_000_000_000_000_000_000
    let json = JSON.ArrayBuilder()
      .add(large)
      .build()

    #expect(json[0] == .number(.integer(large)))
  }

  @Test("array builder float value") func arrayBuilderFloatValue() {
    let json = JSON.ArrayBuilder()
      .add(Float(3.14))
      .build()

    #expect(json[0]?.isFloat == true)
  }

  @Test("array builder array of json") func arrayBuilderArrayOfJSON() {
    let json = JSON.ArrayBuilder()
      .add([.string("x"), .number(.integer(1))])
      .build()

    #expect(json[0]?.isArray == true)
    #expect(json[0]?[0] == .string("x"))
    #expect(json[0]?[1] == .number(.integer(1)))
  }

  @Test("array builder uint") func arrayBuilderUInt() {
    let json = JSON.ArrayBuilder()
      .add(UInt(42))
      .add(UInt(Int64.max))
      .build()

    #expect(json[0] == .number(.integer(42)))
    #expect(json[1] == .number(.integer(Int64.max)))
  }

  @Test("array builder uint64 overflow") func arrayBuilderUInt64Overflow() {
    let big = UInt64(Int64.max) + 1
    let json = JSON.ArrayBuilder()
      .add(big)
      .build()

    #expect(json[0]?.isFloat == true)
    #expect(json[0] == .number(.float(Double(big))))
  }

  @Test("array builder add null") func arrayBuilderAddNull() {
    let json = JSON.ArrayBuilder()
      .add("a")
      .addNull()
      .build()

    #expect(json[1] == .null)
  }

  @Test("array builder append contents of builder") func arrayBuilderAppendContentsOfBuilder() {
    let combined = JSON.ArrayBuilder()
      .add("a")
      .add("b")
      .append(
        contentsOf: JSON.ArrayBuilder()
          .add("c")
          .add("d")
      )
      .build()

    #expect(combined.count == 4)
    #expect(combined[0] == .string("a"))
    #expect(combined[1] == .string("b"))
    #expect(combined[2] == .string("c"))
    #expect(combined[3] == .string("d"))
  }

  @Test("array builder append contents of array") func arrayBuilderAppendContentsOfArray() {
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

  @Test("array builder add if present") func arrayBuilderAddIfPresent() {
    let json = JSON.ArrayBuilder()
      .add("a")
      .addIfPresent("hello" as String?)
      .addIfPresent(nil as String?)
      .addIfPresent(42 as Int?)
      .addIfPresent(nil as Int?)
      .addIfPresent(true as Bool?)
      .addIfPresent(nil as Bool?)
      .build()

    #expect(json.count == 4)
    #expect(json[0] == .string("a"))
    #expect(json[1] == .string("hello"))
    #expect(json[2] == .number(.integer(42)))
    #expect(json[3] == .boolean(true))
  }

  @Test("array builder add if present uint") func arrayBuilderAddIfPresentUInt() {
    let json = JSON.ArrayBuilder()
      .addIfPresent(UInt?(42))
      .addIfPresent(nil as UInt?)
      .build()

    #expect(json.count == 1)
    #expect(json[0] == .number(.integer(42)))
  }

  @Test("array builder add if present json") func arrayBuilderAddIfPresentJSON() {
    let json = JSON.ArrayBuilder()
      .add("a")
      .addIfPresent(JSON?(.string("hello")))
      .addIfPresent(nil as JSON?)
      .build()

    #expect(json.count == 2)
    #expect(json[1] == .string("hello"))
  }

  @Test("array builder add if present object builder") func arrayBuilderAddIfPresentObjectBuilder()
  {
    let json = JSON.ArrayBuilder()
      .add("a")
      .addIfPresent(
        JSON.ObjectBuilder?(
          JSON.ObjectBuilder()
            .set("x", 1)
        )
      )
      .addIfPresent(nil as JSON.ObjectBuilder?)
      .build()

    #expect(json.count == 2)
    #expect(json[1]?.isObject == true)
    #expect(json[1]?["x"] == .number(.integer(1)))
  }

  @Test("array builder add if present array builder") func arrayBuilderAddIfPresentArrayBuilder() {
    let json = JSON.ArrayBuilder()
      .add("a")
      .addIfPresent(
        JSON.ArrayBuilder?(
          JSON.ArrayBuilder()
            .add("inner")
        )
      )
      .addIfPresent(nil as JSON.ArrayBuilder?)
      .build()

    #expect(json.count == 2)
    #expect(json[1]?.isArray == true)
    #expect(json[1]?[0] == .string("inner"))
  }

  @Test("array builder add if present double") func arrayBuilderAddIfPresentDouble() {
    let json = JSON.ArrayBuilder()
      .addIfPresent(3.14 as Double?)
      .addIfPresent(nil as Double?)
      .build()

    #expect(json.count == 1)
    #expect(json[0] == .number(.float(3.14)))
  }

}
