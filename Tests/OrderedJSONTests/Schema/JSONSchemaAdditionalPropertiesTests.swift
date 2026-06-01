import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Object Keywords

@Suite("JSONSchema additionalProperties")
struct JSONSchemaAdditionalPropertiesTests {
  @Test("additionalProperties — valid (key covered by properties)")
  func additionalPropertiesCovered() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object(["name": .object(["type": .string("string")])]),
        "additionalProperties": .boolean(false),
      ]), draft: .draft7
    )
    #expect(schema.validating(.object(["name": .string("Alice")])).valid)
  }

  @Test("additionalProperties — invalid (key not covered)")
  func additionalPropertiesUncovered() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object(["name": .object(["type": .string("string")])]),
        "additionalProperties": .boolean(false),
      ]), draft: .draft7
    )
    let result = schema.validating(
      .object(["name": .string("Alice"), "age": .number(.integer(30))])
    )
    #expect(!result.valid)
    // Error keyword is "false" from the boolean subschema, not "additionalProperties"
    #expect(result.errors.first?.keyword == .falseSchema)
  }

  @Test("additionalProperties — non-object skips")
  func additionalPropertiesNonObject() throws {
    let schema = try JSONSchema(
      schema: .object(["additionalProperties": .boolean(false)]), draft: .draft7
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}
