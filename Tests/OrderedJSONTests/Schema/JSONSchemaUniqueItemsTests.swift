import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Array Keywords

@Suite("JSONSchema uniqueItems")
struct JSONSchemaUniqueItemsTests {
  @Test("uniqueItems — valid (all unique)")
  func uniqueItemsValid() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    #expect(schema.validating(.array([.string("a"), .string("b")])).valid)
  }

  @Test("uniqueItems — invalid (duplicates)")
  func uniqueItemsInvalid() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    let result = schema.validating(.array([.string("a"), .string("a")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .uniqueItems)
  }

  @Test("uniqueItems — false disables check")
  func uniqueItemsFalse() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(false)]))
    #expect(schema.validating(.array([.string("a"), .string("a")])).valid)
  }

  @Test("uniqueItems — non-array skips")
  func uniqueItemsNonArray() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("uniqueItems — integer 1 and float 1.0 are considered equal")
  func uniqueItemsIntFloat() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    let result = schema.validating(.array([.number(.integer(1)), .number(.float(1.0))]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .uniqueItems)
  }
}

// MARK: - UniqueItems Edge Cases

@Suite("JSONSchema uniqueItems edge cases")
struct JSONSchemaUniqueItemsEdgeCasesTests {
  @Test("uniqueItems — objects with same key-value pairs are duplicates")
  func uniqueItemsDuplicateObjects() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    let result = schema.validating(
      .array([
        .object(["a": .number(.integer(1))]),
        .object(["a": .number(.integer(1))]),
      ])
    )
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .uniqueItems)
  }

  @Test("uniqueItems — arrays with same elements are duplicates")
  func uniqueItemsDuplicateArrays() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    let result = schema.validating(
      .array([
        .array([.number(.integer(1)), .number(.integer(2))]),
        .array([.number(.integer(1)), .number(.integer(2))]),
      ])
    )
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .uniqueItems)
  }

  @Test("uniqueItems — nested structures with same content")
  func uniqueItemsNestedDuplicates() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    let result = schema.validating(
      .array([
        .object(["inner": .array([.number(.integer(1))])]),
        .object(["inner": .array([.number(.integer(1))])]),
      ])
    )
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .uniqueItems)
  }

  @Test("uniqueItems — empty array trivially passes")
  func uniqueItemsEmptyArray() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    #expect(schema.validating(.array([])).valid)
  }

  @Test("uniqueItems — single element trivially passes")
  func uniqueItemsSingleElement() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    #expect(schema.validating(.array([.string("a")])).valid)
  }
}
