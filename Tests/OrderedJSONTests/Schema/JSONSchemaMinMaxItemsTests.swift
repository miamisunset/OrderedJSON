import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Array Keywords

@Suite("JSONSchema minItems / maxItems")
struct JSONSchemaMinMaxItemsTests {
  @Test("minItems — valid")
  func minItemsValid() throws {
    let schema = try JSONSchema(schema: .object(["minItems": .number(.integer(2))]))
    #expect(schema.validating(.array([.string("a"), .string("b")])).valid)
    #expect(schema.validating(.array([.string("a"), .string("b"), .string("c")])).valid)
  }

  @Test("minItems — invalid")
  func minItemsInvalid() throws {
    let schema = try JSONSchema(schema: .object(["minItems": .number(.integer(3))]))
    let result = schema.validating(.array([.string("a"), .string("b")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "minItems")
  }

  @Test("maxItems — valid")
  func maxItemsValid() throws {
    let schema = try JSONSchema(schema: .object(["maxItems": .number(.integer(3))]))
    #expect(schema.validating(.array([.string("a"), .string("b")])).valid)
    #expect(schema.validating(.array([.string("a")])).valid)
  }

  @Test("maxItems — invalid")
  func maxItemsInvalid() throws {
    let schema = try JSONSchema(schema: .object(["maxItems": .number(.integer(2))]))
    let result = schema.validating(.array([.string("a"), .string("b"), .string("c")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "maxItems")
  }

  @Test("minItems / maxItems — non-array skips")
  func minMaxItemsNonArray() throws {
    let schema = try JSONSchema(
      schema: .object(["minItems": .number(.integer(2)), "maxItems": .number(.integer(5))])
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}
