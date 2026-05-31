import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - minContains / maxContains Edge Cases

@Suite("JSONSchema minContains / maxContains edge cases")
struct JSONSchemaMinMaxContainsEdgeCasesTests {
  @Test("minContains — valid when enough matches")
  func minContainsValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "minContains": .number(.integer(2)),
      ])
    )
    #expect(schema.validating(.array([.string("a"), .string("b"), .number(.integer(1))])).valid)
  }

  @Test("minContains — invalid when not enough matches")
  func minContainsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "minContains": .number(.integer(2)),
      ])
    )
    let result = schema.validating(.array([.string("a"), .number(.integer(1))]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "minContains")
  }

  @Test("maxContains — valid when within limit")
  func maxContainsValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "maxContains": .number(.integer(2)),
      ])
    )
    #expect(schema.validating(.array([.string("a"), .string("b")])).valid)
  }

  @Test("maxContains — invalid when too many matches")
  func maxContainsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "maxContains": .number(.integer(1)),
      ])
    )
    let result = schema.validating(.array([.string("a"), .string("b")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "maxContains")
  }

  @Test("minContains 0 — no constraint (per spec)")
  func minContainsZero() throws {
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "minContains": .number(.integer(0)),
      ])
    )
    #expect(schema.validating(.array([.number(.integer(1)), .number(.integer(2))])).valid)
  }
}
