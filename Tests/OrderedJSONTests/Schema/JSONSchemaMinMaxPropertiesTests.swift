import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Object Keywords

@Suite("JSONSchema minProperties / maxProperties")
struct JSONSchemaMinMaxPropertiesTests {
  @Test("minProperties — valid")
  func minPropertiesValid() throws {
    let schema = try JSONSchema(schema: .object(["minProperties": .number(.integer(1))]))
    #expect(schema.validating(.object(["a": .string("x")])).valid)
    #expect(schema.validating(.object(["a": .string("x"), "b": .string("y")])).valid)
  }

  @Test("minProperties — invalid")
  func minPropertiesInvalid() throws {
    let schema = try JSONSchema(schema: .object(["minProperties": .number(.integer(2))]))
    let result = schema.validating(.object(["a": .string("x")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .minProperties)
  }

  @Test("maxProperties — valid")
  func maxPropertiesValid() throws {
    let schema = try JSONSchema(schema: .object(["maxProperties": .number(.integer(3))]))
    #expect(schema.validating(.object(["a": .string("x")])).valid)
    #expect(schema.validating(.object(["a": .string("x"), "b": .string("y")])).valid)
  }

  @Test("maxProperties — invalid")
  func maxPropertiesInvalid() throws {
    let schema = try JSONSchema(schema: .object(["maxProperties": .number(.integer(1))]))
    let result = schema.validating(.object(["a": .string("x"), "b": .string("y")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .maxProperties)
  }

  @Test("minProperties / maxProperties — non-object skips")
  func minMaxPropertiesNonObject() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minProperties": .number(.integer(2)), "maxProperties": .number(.integer(5)),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}
