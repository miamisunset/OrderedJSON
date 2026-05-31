import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Array Keywords

@Suite("JSONSchema items")
struct JSONSchemaItemsTests {
  @Test("items — schema mode (Draft 2020-12) — valid")
  func itemsSchemaValid() throws {
    let schema = try JSONSchema(schema: .object(["items": .object(["type": .string("string")])]))
    #expect(schema.validating(.array([.string("a"), .string("b")])).valid)
  }

  @Test("items — schema mode — invalid")
  func itemsSchemaInvalid() throws {
    let schema = try JSONSchema(schema: .object(["items": .object(["type": .string("string")])]))
    let result = schema.validating(.array([.string("a"), .number(.integer(1))]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("items")
        || result.errors.map(\.keyword).contains("type")
    )
    #expect(result.errors.count >= 1)
  }

  @Test("items — Draft 7 tuple mode — valid")
  func itemsTupleDraft7Valid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "items": .array([
          .object(["type": .string("string")]),
          .object(["type": .string("number")]),
        ])
      ]), draft: .draft7
    )
    #expect(schema.validating(.array([.string("a"), .number(.integer(1))])).valid)
  }

  @Test("items — Draft 7 tuple mode — invalid")
  func itemsTupleDraft7Invalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "items": .array([
          .object(["type": .string("string")]),
          .object(["type": .string("number")]),
        ])
      ]), draft: .draft7
    )
    let result = schema.validating(.array([.string("a"), .string("b")]))
    #expect(!result.valid)
  }

  @Test("items — non-array value skips")
  func itemsNonArray() throws {
    let schema = try JSONSchema(schema: .object(["items": .object(["type": .string("string")])]))
    #expect(schema.validating(.string("hello")).valid)
  }
}
