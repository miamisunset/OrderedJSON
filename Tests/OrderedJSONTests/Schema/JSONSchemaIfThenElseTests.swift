import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Composition: if/then/else

@Suite("JSONSchema if/then/else")
struct JSONSchemaIfThenElseTests {
  @Test("if/then — valid when if matches and then matches")
  func ifThenValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "then": .object(["minLength": .number(.integer(3))]),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("if/then — invalid when if matches but then fails")
  func ifThenInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "then": .object(["minLength": .number(.integer(10))]),
      ])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "then")
  }

  @Test("if/else — valid when if fails and else matches")
  func ifElseValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "else": .object(["minLength": .number(.integer(3))]),
      ])
    )
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("if/else — invalid when if fails and else fails")
  func ifElseInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "else": .object(["type": .string("string")]),
      ])
    )
    let result = schema.validating(.number(.integer(42)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "else")
  }

  @Test("if alone — no then/else, if result doesn't affect validity")
  func ifAlone() throws {
    let schema = try JSONSchema(schema: .object(["if": .object(["type": .string("number")])]))
    #expect(schema.validating(.string("test")).valid)
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("if/then/else — full conditional")
  func ifThenElseFull() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("number")]),
        "then": .object(["minimum": .number(.integer(0))]),
        "else": .object(["type": .string("string")]),
      ])
    )
    #expect(schema.validating(.number(.integer(42))).valid)
    #expect(schema.validating(.number(.integer(-1))).valid == false)
    #expect(schema.validating(.string("test")).valid)
    #expect(schema.validating(.boolean(true)).valid == false)
  }
}

// MARK: - If/Then/Else Edge Cases

@Suite("JSONSchema if/then/else edge cases")
struct JSONSchemaIfThenElseEdgeCasesTests {
  @Test("if/then — boolean false then fails when if passes")
  func ifThenBooleanFalse() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "then": .boolean(false),
      ])
    )
    #expect(!schema.validating(.string("hello")).valid)
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("if/else — boolean false else fails when if fails")
  func ifElseBooleanFalse() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "else": .boolean(false),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }

  @Test("if alone with boolean if schema")
  func ifBooleanSchema() throws {
    let schema = try JSONSchema(schema: .object(["if": .boolean(false)]))
    #expect(schema.validating(.string("anything")).valid)
  }

  @Test("if/then — if is true boolean, then is always checked")
  func ifTrueThenChecked() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .boolean(true),
        "then": .object(["type": .string("number")]),
      ])
    )
    #expect(schema.validating(.number(.integer(42))).valid)
    #expect(!schema.validating(.string("hello")).valid)
  }
}
