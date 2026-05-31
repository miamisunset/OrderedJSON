import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Array Keywords

@Suite("JSONSchema additionalItems")
struct JSONSchemaAdditionalItemsTests {
  @Test("additionalItems — Draft 7 valid (items beyond tuple pass)")
  func additionalItemsValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "items": .array([.object(["type": .string("string")])]),
        "additionalItems": .object(["type": .string("number")]),
      ]), draft: .draft7
    )
    #expect(schema.validating(.array([.string("a"), .number(.integer(1))])).valid)
  }

  @Test("additionalItems — Draft 7 invalid (beyond tuple fails)")
  func additionalItemsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "items": .array([.object(["type": .string("string")])]),
        "additionalItems": .object(["type": .string("number")]),
      ]), draft: .draft7
    )
    let result = schema.validating(.array([.string("a"), .string("b")]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("additionalItems")
        || result.errors.map(\.keyword).contains("type")
    )
    #expect(result.errors.count >= 1)
  }

  @Test("additionalItems — non-array skips")
  func additionalItemsNonArray() throws {
    let schema = try JSONSchema(
      schema: .object(["additionalItems": .object(["type": .string("string")])]), draft: .draft7
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}
