import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Composition: not

@Suite("JSONSchema not")
struct JSONSchemaNotTests {
  @Test("not — valid when subschema does NOT match")
  func notValid() throws {
    let schema = try JSONSchema(
      schema: .object(["not": .object(["type": .string("number")])])
    )
    #expect(schema.validating(.string("test")).valid)
  }

  @Test("not — invalid when subschema matches")
  func notInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["not": .object(["type": .string("string")])])
    )
    let result = schema.validating(.string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "not")
  }

  @Test("not — missing keyword skips")
  func notMissing() throws {
    let schema = try JSONSchema(schema: .object([:]))
    #expect(schema.validating(.string("test")).valid)
  }
}
