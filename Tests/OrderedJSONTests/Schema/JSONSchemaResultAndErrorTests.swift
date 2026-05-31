import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Result & Error

@Suite("JSONSchema result and error")
struct JSONSchemaResultTests {
  @Test("result — valid is true when no errors")
  func resultValidTrue() throws {
    let schema = try JSONSchema(schema: .object([:]))
    let result = schema.validating(.string("hello"))
    #expect(result.valid)
    #expect(result.errors.isEmpty)
  }

  @Test("result — valid is false when errors")
  func resultValidFalse() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.count == 1)
  }

  @Test("error description includes keyword and message")
  func errorDescription() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    let result = schema.validating(.string("hello"))
    let desc = try String(describing: #require(result.errors.first))
    #expect(desc.contains("type"))
    #expect(desc.contains("expected"))
  }

  @Test("throwOnError throws on first error")
  func throwOnError() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    let result = schema.validating(.string("hello"))
    #expect(throws: JSONSchemaError.self) {
      try result.throwOnError()
    }
  }

  @Test("throwOnError does nothing on valid result")
  func throwOnErrorNoop() throws {
    let schema = try JSONSchema(schema: .object([:]))
    let result = schema.validating(.string("hello"))
    try result.throwOnError()  // should not throw
  }
}
