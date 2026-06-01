import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Array Keywords

@Suite("JSONSchema unevaluatedItems")
struct JSONSchemaUnevaluatedItemsTests {
  @Test("unevaluatedItems — valid (items beyond prefix pass)")
  func unevaluatedItemsValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "prefixItems": .array([.object(["type": .string("string")])]),
        "unevaluatedItems": .object(["type": .string("number")]),
      ])
    )
    #expect(schema.validating(.array([.string("a"), .number(.integer(1))])).valid)
  }

  @Test("unevaluatedItems — invalid (beyond prefix fails)")
  func unevaluatedItemsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "prefixItems": .array([.object(["type": .string("string")])]),
        "unevaluatedItems": .object(["type": .string("number")]),
      ])
    )
    let result = schema.validating(.array([.string("a"), .string("b")]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains(.unevaluatedItems)
        || result.errors.map(\.keyword).contains(.type)
    )
    #expect(result.errors.count >= 1)
  }

  @Test("unevaluatedItems — non-array skips")
  func unevaluatedItemsNonArray() throws {
    let schema = try JSONSchema(
      schema: .object(["unevaluatedItems": .object(["type": .string("string")])])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("unevaluatedItems — items schema short-circuits unevaluatedItems")
  func unevaluatedItemsWithItemsSchema() throws {
    // When `items` is a schema, it evaluates all items past prefixItems,
    // so unevaluatedItems should be a no-op.
    let schema = try JSONSchema(
      schema: .object([
        "items": .object(["type": .string("string")]),
        "unevaluatedItems": .boolean(false),
      ])
    )
    let result = schema.validating(.array([.string("a"), .string("b")]))
    #expect(result.valid)
  }

  @Test("unevaluatedItems — contains matched indices not excluded (known deviation)")
  func unevaluatedItemsWithContains() throws {
    // Per spec, items matched by contains are evaluated and should be excluded
    // from unevaluatedItems. Currently they are not.
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["const": .number(.integer(1))]),
        "unevaluatedItems": .boolean(false),
      ])
    )
    // Current behavior: unevaluatedItems fires on index 0 (which contains matched).
    let result = schema.validating(.array([.number(.integer(1)), .number(.integer(2))]))
    // Current (deviant): fails — unevaluatedItems fires on index 0
    #expect(!result.valid)
  }
}
