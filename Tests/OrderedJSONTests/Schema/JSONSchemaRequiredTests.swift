import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Required Validation

@Suite("JSONSchema required validation")
struct JSONSchemaRequiredTests {
  @Test("required — valid when all present")
  func requiredValid() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("a"), .string("b")])])
    )
    let doc: JSON = .object(["a": .string("x"), "b": .string("y")])
    #expect(schema.validating(doc).valid)
  }

  @Test("required — fails when missing")
  func requiredMissing() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("name")])])
    )
    let doc: JSON = .object(["age": .number(.integer(30))])
    let result = schema.validating(doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "required")
  }

  @Test("required — null is valid (spec: presence only)")
  func requiredNullValid() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("name")])])
    )
    let doc: JSON = .object(["name": .null])
    #expect(schema.validating(doc).valid)
  }

  @Test("required — non-object skips validation")
  func requiredNonObject() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("name")])])
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}

// MARK: - Required Edge Cases

@Suite("JSONSchema required edge cases")
struct JSONSchemaRequiredEdgeCasesTests {
  @Test("required — empty array always passes")
  func requiredEmptyArray() throws {
    let schema = try JSONSchema(schema: .object(["required": .array([])]))
    #expect(schema.validating(.object(["a": .string("x")])).valid)
    #expect(schema.validating(.object([:])).valid)
  }

  @Test("required — non-array value ignored")
  func requiredNonArrayIgnored() throws {
    let schema = try JSONSchema(schema: .object(["required": .string("not-an-array")]))
    #expect(schema.validating(.object(["a": .string("x")])).valid)
  }

  @Test("required — non-string element produces error but continues")
  func requiredNonStringElement() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("a"), .number(.integer(42))])]))
    let result = schema.validating(.object(["a": .string("x")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "required")
  }
}
