import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Composition: anyOf

@Suite("JSONSchema anyOf")
struct JSONSchemaAnyOfTests {
  @Test("anyOf — valid when at least one matches")
  func anyOfValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "anyOf": .array([
          .object(["type": .string("number")]),
          .object(["type": .string("string")]),
        ])
      ])
    )
    #expect(schema.validating(.string("test")).valid)
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("anyOf — invalid when none match")
  func anyOfInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "anyOf": .array([
          .object(["type": .string("number")]),
          .object(["type": .string("boolean")]),
        ])
      ])
    )
    let result = schema.validating(.string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .anyOf)
  }

  @Test("anyOf — empty array fails (no subschemas to match)")
  func anyOfEmpty() throws {
    let schema = try JSONSchema(schema: .object(["anyOf": .array([])]))
    let result = schema.validating(.string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .anyOf)
  }
}
