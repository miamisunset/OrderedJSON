import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - $dynamicRef Edge Cases

@Suite("JSONSchema $dynamicRef edge cases")
struct JSONSchemaDynamicRefEdgeCasesTests {
  @Test("$dynamicRef — no fragment behaves like $ref")
  func dynamicRefNoFragment() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object(["strType": .object(["type": .string("string")])]),
        "$dynamicRef": .string("#/$defs/strType"),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }
}
