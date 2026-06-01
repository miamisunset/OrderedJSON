import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Const

@Suite("JSONSchema const")
struct JSONSchemaConstTests {
  @Test("const — valid match")
  func constValid() throws {
    let schema = try JSONSchema(
      schema: .object(["const": .string("hello")])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("const — invalid mismatch")
  func constInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["const": .string("hello")])
    )
    let result = schema.validating(.string("world"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .const)
  }

  @Test("const — string match")
  func constStringMatch() throws {
    let schema = try JSONSchema(
      schema: .object(["const": .string("test")])
    )
    #expect(schema.validating(.string("test")).valid)
  }

  @Test("const — object match")
  func constObjectMatch() throws {
    let schema = try JSONSchema(
      schema: .object(["const": .object(["a": .number(.integer(1))])])
    )
    #expect(schema.validating(.object(["a": .number(.integer(1))])).valid)
  }
}
