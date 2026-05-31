import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Boolean Schema Edge Cases

@Suite("JSONSchema boolean schema edge cases")
struct JSONSchemaBooleanEdgeCasesTests {
  @Test("false schema in allOf — allOf fails")
  func falseInAllOf() throws {
    let schema = try JSONSchema(
      schema: .object([
        "allOf": .array([.boolean(true), .boolean(false)])
      ])
    )
    let result = schema.validating(.string("anything"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "allOf")
  }

  @Test("false schema in anyOf — anyOf fails when all false")
  func falseInAnyOf() throws {
    let schema = try JSONSchema(
      schema: .object([
        "anyOf": .array([.boolean(false), .boolean(false)])
      ])
    )
    let result = schema.validating(.string("anything"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "anyOf")
  }

  @Test("true schema in anyOf — anyOf passes with at least one true")
  func trueInAnyOf() throws {
    let schema = try JSONSchema(
      schema: .object([
        "anyOf": .array([.boolean(false), .boolean(true)])
      ])
    )
    #expect(schema.validating(.string("anything")).valid)
  }

  @Test("oneOf — two true boolean schemas fail (not exactly one)")
  func oneOfTwoTrueBooleans() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([.boolean(true), .boolean(true)])
      ])
    )
    let result = schema.validating(.string("anything"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "oneOf")
    #expect(result.errors.first?.message.contains("2") == true)
  }

  @Test("oneOf — one true boolean schema passes")
  func oneOfOneTrueBoolean() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([.boolean(false), .boolean(true)])
      ])
    )
    #expect(schema.validating(.string("anything")).valid)
  }
}
