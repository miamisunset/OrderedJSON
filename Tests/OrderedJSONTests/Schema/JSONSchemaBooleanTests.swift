import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Boolean Schemas

@Suite("JSONSchema boolean schemas")
struct JSONSchemaBooleanTests {
  @Test("true schema — accepts everything")
  func trueSchema() throws {
    let schema = try JSONSchema(schema: .boolean(true))
    #expect(schema.validating(.null).valid)
    #expect(schema.validating(.boolean(true)).valid)
    #expect(schema.validating(.number(.integer(42))).valid)
    #expect(schema.validating(.string("hello")).valid)
    #expect(schema.validating(.array([.number(.integer(1))])).valid)
    #expect(schema.validating(.object([:])).valid)
  }

  @Test("false schema — rejects everything")
  func falseSchema() throws {
    let schema = try JSONSchema(schema: .boolean(false))
    #expect(!schema.validating(.null).valid)
    #expect(!schema.validating(.boolean(true)).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
    #expect(!schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.array([.number(.integer(1))])).valid)
    #expect(!schema.validating(.object([:])).valid)
  }

  @Test("boolean schema — error message is 'false'")
  func falseSchemaErrorKeyword() throws {
    let schema = try JSONSchema(schema: .boolean(false))
    let result = schema.validating(.string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "false")
  }
}
