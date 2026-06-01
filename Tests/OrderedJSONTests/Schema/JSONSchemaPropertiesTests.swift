import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Properties Validation

@Suite("JSONSchema properties validation")
struct JSONSchemaPropertiesTests {
  @Test("properties — valid nested")
  func propertiesValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "name": .object(["type": .string("string")])
        ])
      ])
    )
    let doc: JSON = .object(["name": .string("Alice")])
    #expect(schema.validating(doc).valid)
  }

  @Test("properties — invalid nested")
  func propertiesInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "age": .object(["type": .string("integer")])
        ])
      ])
    )
    let doc: JSON = .object(["age": .string("thirty")])
    let result = schema.validating(doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .type)
  }

  @Test("properties — missing key doesn't fail (not required)")
  func propertiesMissingKey() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "name": .object(["type": .string("string")])
        ])
      ])
    )
    let doc: JSON = .object([:])
    #expect(schema.validating(doc).valid)
  }

  @Test("properties — non-object value skips validation")
  func propertiesNonObject() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "name": .object(["type": .string("string")])
        ])
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}
