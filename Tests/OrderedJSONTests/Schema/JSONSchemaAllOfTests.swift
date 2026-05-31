import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Composition: allOf

@Suite("JSONSchema allOf")
struct JSONSchemaAllOfTests {
  @Test("allOf — valid when all subschemas match")
  func allOfValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "allOf": .array([
          .object(["type": .string("string")]),
          .object(["minLength": .number(.integer(3))]),
        ])
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("allOf — invalid when one subschema fails")
  func allOfInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "allOf": .array([
          .object(["type": .string("string")]),
          .object(["minLength": .number(.integer(10))]),
        ])
      ])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "allOf")
  }

  @Test("allOf — empty array passes")
  func allOfEmpty() throws {
    let schema = try JSONSchema(schema: .object(["allOf": .array([])]))
    #expect(schema.validating(.string("anything")).valid)
  }

  @Test("allOf — missing keyword skips")
  func allOfMissing() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    #expect(schema.validating(.string("test")).valid)
  }
}
