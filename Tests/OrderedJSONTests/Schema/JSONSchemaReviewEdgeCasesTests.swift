import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Review edge cases

@Suite("JSONSchema review edge cases")
struct JSONSchemaReviewEdgeCasesTests {
  @Test("not — with false boolean subschema (passes everything)")
  func notWithFalseSchema() throws {
    let schema = try JSONSchema(schema: .object(["not": .boolean(false)]))
    #expect(schema.validating(.string("anything")).valid)
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("not — with true boolean subschema (rejects everything)")
  func notWithTrueSchema() throws {
    let schema = try JSONSchema(schema: .object(["not": .boolean(true)]))
    #expect(!schema.validating(.string("anything")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
    #expect(!schema.validating(.null).valid)
  }

  @Test("dependentSchemas — with false value (rejects when key present)")
  func depSchemasWithFalse() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "credit_card": .boolean(false)
        ])
      ])
    )
    #expect(schema.validating(.object(["name": .string("Alice")])).valid)
    let result = schema.validating(.object(["credit_card": .string("1234")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "dependentSchemas")
  }

  @Test("if/then — with boolean then (false rejects when if passes)")
  func ifThenBoolean() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "then": .boolean(false),
      ])
    )
    #expect(!schema.validating(.string("hello")).valid)
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("minLength — multi-scalar grapheme (code point semantics)")
  func minLengthMultiScalar() throws {
    let familyEmoji = "👨‍👩‍👧"
    let schema = try JSONSchema(schema: .object(["minLength": .number(.integer(5))]))
    #expect(schema.validating(.string(familyEmoji)).valid)
  }

  @Test("maxLength — multi-scalar grapheme (code point semantics)")
  func maxLengthMultiScalar() throws {
    let familyEmoji = "👨‍👩‍👧"
    let schema = try JSONSchema(schema: .object(["maxLength": .number(.integer(4))]))
    #expect(!schema.validating(.string(familyEmoji)).valid)
  }

  @Test("boolean schema init — true accepts everything")
  func booleanTrueInit() throws {
    let schema = try JSONSchema(schema: .boolean(true))
    #expect(schema.validating(.null).valid)
    #expect(schema.validating(.boolean(false)).valid)
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("boolean schema init — false rejects everything")
  func booleanFalseInit() throws {
    let schema = try JSONSchema(schema: .boolean(false))
    #expect(!schema.validating(.null).valid)
    #expect(!schema.validating(.string("x")).valid)
  }

  @Test("nested composition — allOf > anyOf > oneOf")
  func nestedComposition() throws {
    let schema = try JSONSchema(
      schema: .object([
        "allOf": .array([
          .object([
            "anyOf": .array([
              .object(["type": .string("string")]),
              .object(["type": .string("number")]),
            ])
          ]),
          .object([
            "oneOf": .array([
              .object(["minimum": .number(.integer(10))]),
              .object(["maximum": .number(.integer(0))]),
            ])
          ]),
        ])
      ])
    )
    #expect(schema.validating(.number(.integer(42))).valid)
    #expect(!schema.validating(.number(.integer(5))).valid)
  }
}
