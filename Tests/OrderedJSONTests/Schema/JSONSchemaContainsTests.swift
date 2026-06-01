import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Array Keywords

@Suite("JSONSchema contains")
struct JSONSchemaContainsTests {
  @Test("contains — valid (at least one matches)")
  func containsValid() throws {
    let schema = try JSONSchema(schema: .object(["contains": .object(["type": .string("string")])]))
    #expect(schema.validating(.array([.number(.integer(1)), .string("hello")])).valid)
  }

  @Test("contains — invalid (none match)")
  func containsInvalid() throws {
    let schema = try JSONSchema(schema: .object(["contains": .object(["type": .string("string")])]))
    let result = schema.validating(.array([.number(.integer(1)), .number(.integer(2))]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .contains)
  }

  @Test("contains — empty array fails")
  func containsEmpty() throws {
    let schema = try JSONSchema(schema: .object(["contains": .object(["type": .string("string")])]))
    let result = schema.validating(.array([]))
    #expect(!result.valid)
  }

  @Test("contains — non-array skips")
  func containsNonArray() throws {
    let schema = try JSONSchema(schema: .object(["contains": .object(["type": .string("string")])]))
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("contains — minContains/maxContains now enforced")
  func containsMinContainsEnforced() throws {
    // minContains is now enforced — 2 required but only 1 match
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "minContains": .number(.integer(2)),
      ])
    )
    #expect(!schema.validating(.array([.number(.integer(1)), .string("hello")])).valid)
  }
}
