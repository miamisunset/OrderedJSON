import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Array Keywords

@Suite("JSONSchema prefixItems")
struct JSONSchemaPrefixItemsTests {
  @Test("prefixItems — valid")
  func prefixItemsValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "prefixItems": .array([
          .object(["type": .string("string")]),
          .object(["type": .string("number")]),
        ])
      ])
    )
    #expect(schema.validating(.array([.string("a"), .number(.integer(1))])).valid)
  }

  @Test("prefixItems — invalid")
  func prefixItemsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "prefixItems": .array([
          .object(["type": .string("string")])
        ])
      ])
    )
    let result = schema.validating(.array([.number(.integer(1))]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("prefixItems")
        || result.errors.map(\.keyword).contains("type")
    )
    #expect(result.errors.count >= 1)
  }

  @Test("prefixItems — non-array value skips")
  func prefixItemsNonArray() throws {
    let schema = try JSONSchema(
      schema: .object(["prefixItems": .array([.object(["type": .string("string")])])])
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}
