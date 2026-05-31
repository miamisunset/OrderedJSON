import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Object Keywords

@Suite("JSONSchema propertyNames")
struct JSONSchemaPropertyNamesTests {
  @Test("propertyNames — valid (key matches schema)")
  func propertyNamesValid() throws {
    let schema = try JSONSchema(
      schema: .object(["propertyNames": .object(["pattern": .string("^[a-z]+$")])])
    )
    #expect(schema.validating(.object(["name": .string("Alice")])).valid)
  }

  @Test("propertyNames — invalid (key fails schema)")
  func propertyNamesInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["propertyNames": .object(["pattern": .string("^[a-z]+$")])])
    )
    let result = schema.validating(.object(["NAME": .string("Alice")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "propertyNames")
  }

  @Test("propertyNames — non-object skips")
  func propertyNamesNonObject() throws {
    let schema = try JSONSchema(
      schema: .object(["propertyNames": .object(["type": .string("string")])])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("propertyNames — inner dispatch preserves parent keyword")
  func propertyNamesInnerDispatch() throws {
    // propertyNames wraps errors with its own keyword (not the inner keyword).
    let schema = try JSONSchema(
      schema: .object(["propertyNames": .object(["maxLength": .number(.integer(3))])])
    )
    let result = schema.validating(.object(["abcd": .number(.integer(1))]))
    #expect(!result.valid)
    // The error keyword is "propertyNames" (parent wraps inner errors)
    #expect(result.errors.first?.keyword == "propertyNames")
  }
}
