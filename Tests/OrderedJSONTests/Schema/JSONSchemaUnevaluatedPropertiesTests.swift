import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Object Keywords

@Suite("JSONSchema unevaluatedProperties")
struct JSONSchemaUnevaluatedPropertiesTests {
  @Test("unevaluatedProperties — valid (key evaluated by properties)")
  func unevaluatedPropertiesCovered() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object(["name": .object(["type": .string("string")])]),
        "unevaluatedProperties": .boolean(false),
      ])
    )
    #expect(schema.validating(.object(["name": .string("Alice")])).valid)
  }

  @Test("unevaluatedProperties — invalid (key not evaluated)")
  func unevaluatedPropertiesUncovered() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object(["name": .object(["type": .string("string")])]),
        "unevaluatedProperties": .boolean(false),
      ])
    )
    let result = schema.validating(
      .object(["name": .string("Alice"), "age": .number(.integer(30))])
    )
    #expect(!result.valid)
    // Error keyword is "false" from the boolean subschema, not "unevaluatedProperties"
    #expect(result.errors.first?.keyword == "false")
  }

  @Test("unevaluatedProperties — additionalProperties now tracked")
  func unevaluatedPropertiesWithAdditionalProperties() throws {
    // Keys evaluated by additionalProperties are now in the evaluated set,
    // so unevaluatedProperties does not re-check them.
    let schema = try JSONSchema(
      schema: .object([
        "additionalProperties": .object(["type": .string("string")]),
        "unevaluatedProperties": .boolean(false),
      ])
    )
    // All keys are evaluated by additionalProperties, so unevaluatedProperties
    // has nothing to check — the schema validates successfully.
    let result = schema.validating(.object(["x": .string("hello")]))
    #expect(result.valid)
  }

  @Test("unevaluatedProperties — non-object skips")
  func unevaluatedPropertiesNonObject() throws {
    let schema = try JSONSchema(schema: .object(["unevaluatedProperties": .boolean(false)]))
    #expect(schema.validating(.string("hello")).valid)
  }
}
