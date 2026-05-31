import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - validate() throws / isValid()

@Suite("JSONSchema throwing and predicate API")
struct JSONSchemaThrowingAPITests {
  @Test("validate — valid returns true")
  func validateValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    #expect(try schema.validate(.string("hello")))
  }

  @Test("validate — invalid throws")
  func validateInvalid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    #expect(throws: JSONSchemaError.self) {
      try schema.validate(.string("hello"))
    }
  }

  @Test("isValid — returns true for valid document")
  func isValidTrue() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    #expect(schema.isValid(.string("hello")))
  }

  @Test("isValid — returns false for invalid document")
  func isValidFalse() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    #expect(!schema.isValid(.string("hello")))
  }

  @Test("validate — first error thrown, rest are lost")
  func validateFirstError() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "minimum": .number(.integer(100)),
      ])
    )
    #expect(throws: JSONSchemaError.self) {
      try schema.validate(.number(.integer(5)))
    }
  }
}
