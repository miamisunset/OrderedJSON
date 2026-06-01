import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Composition: oneOf

@Suite("JSONSchema oneOf")
struct JSONSchemaOneOfTests {
  @Test("oneOf — valid when exactly one matches")
  func oneOfValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([
          .object(["type": .string("number")]),
          .object(["type": .string("string")]),
        ])
      ])
    )
    #expect(schema.validating(.string("test")).valid)
  }

  @Test("oneOf — invalid when zero match")
  func oneOfZeroMatch() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([
          .object(["type": .string("number")]),
          .object(["type": .string("boolean")]),
        ])
      ])
    )
    let result = schema.validating(.string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .oneOf)
  }

  @Test("oneOf — invalid when two match (not exactly one)")
  func oneOfTwoMatch() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([
          .object(["type": .string("string"), "minLength": .number(.integer(1))]),
          .object(["type": .string("string"), "maxLength": .number(.integer(100))]),
        ])
      ])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .oneOf)
    #expect(result.errors.first?.message.contains("2") == true)
  }

  @Test("oneOf — empty array fails")
  func oneOfEmpty() throws {
    let schema = try JSONSchema(schema: .object(["oneOf": .array([])]))
    let result = schema.validating(.string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .oneOf)
  }
}

// MARK: - OneOf Edge Cases

@Suite("JSONSchema oneOf edge cases")
struct JSONSchemaOneOfEdgeCasesTests {
  @Test("oneOf — zero matches produces count 0 in message")
  func oneOfZeroMatches() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([
          .object(["type": .string("number")]),
          .object(["type": .string("boolean")]),
        ])
      ])
    )
    let result = schema.validating(.string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .oneOf)
    #expect(result.errors.first?.message.contains("0") == true)
  }

  @Test("oneOf — two matches produces count 2 in message (short-circuits)")
  func oneOfTwoMatches() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([
          .object(["type": .string("string")]),
          .object(["minLength": .number(.integer(1))]),
          .object(["maxLength": .number(.integer(100))]),
        ])
      ])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .oneOf)
    #expect(result.errors.first?.message.contains("2") == true)
  }
}
