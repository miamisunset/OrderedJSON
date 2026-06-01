import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Composition: dependentSchemas

@Suite("JSONSchema dependentSchemas")
struct JSONSchemaDependentSchemasTests {
  @Test("dependentSchemas — valid when dependency key is absent")
  func depSchemasKeyAbsent() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "credit_card": .object(["required": .array([.string("number")])])
        ])
      ])
    )
    let doc: JSON = .object(["name": .string("Alice")])
    #expect(schema.validating(doc).valid)
  }

  @Test("dependentSchemas — valid when dependency key is present and schema matches")
  func depSchemasValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "credit_card": .object(["required": .array([.string("number")])])
        ])
      ])
    )
    let doc: JSON = .object(["credit_card": .string("1234"), "number": .string("1234")])
    #expect(schema.validating(doc).valid)
  }

  @Test("dependentSchemas — invalid when dependency key is present and schema fails")
  func depSchemasInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "credit_card": .object(["required": .array([.string("number"), .string("cvc")])])
        ])
      ])
    )
    let doc: JSON = .object(["credit_card": .string("1234"), "number": .string("1234")])
    let result = schema.validating(doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .dependentSchemas)
  }

  @Test("dependentSchemas — multiple dependency keys")
  func depSchemasMultiple() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "a": .object(["required": .array([.string("b")])]),
          "b": .object(["required": .array([.string("a")])]),
        ])
      ])
    )
    let doc: JSON = .object(["a": .string("x"), "b": .string("y")])
    #expect(schema.validating(doc).valid)
  }
}
