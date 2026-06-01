import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Exclusive Bounds

@Suite("JSONSchema exclusive bounds")
struct JSONSchemaExclusiveBoundsTests {
  @Test("exclusiveMinimum — Draft 2020-12 valid")
  func exclMin202012Valid() throws {
    let schema = try JSONSchema(
      schema: .object(["exclusiveMinimum": .number(.integer(10))])
    )
    #expect(schema.validating(.number(.integer(11))).valid)
    #expect(schema.validating(.number(.integer(20))).valid)
  }

  @Test("exclusiveMinimum — Draft 2020-12 invalid (equal)")
  func exclMin202012Invalid() throws {
    let schema = try JSONSchema(
      schema: .object(["exclusiveMinimum": .number(.integer(10))])
    )
    let result = schema.validating(.number(.integer(10)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .exclusiveMinimum)
  }

  @Test("exclusiveMinimum — Draft 7 with boolean true")
  func exclMinDraft7BoolTrue() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minimum": .number(.integer(10)),
        "exclusiveMinimum": .boolean(true),
      ]), draft: .draft7
    )
    #expect(schema.validating(.number(.integer(11))).valid)
    let result = schema.validating(.number(.integer(10)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .exclusiveMinimum)
  }

  @Test("exclusiveMinimum — Draft 7 with boolean false (allowed)")
  func exclMinDraft7BoolFalse() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minimum": .number(.integer(10)),
        "exclusiveMinimum": .boolean(false),
      ]), draft: .draft7
    )
    #expect(schema.validating(.number(.integer(10))).valid)
    #expect(schema.validating(.number(.integer(5))).valid == false)
  }

  @Test("exclusiveMaximum — Draft 2020-12 valid")
  func exclMax202012Valid() throws {
    let schema = try JSONSchema(
      schema: .object(["exclusiveMaximum": .number(.integer(100))])
    )
    #expect(schema.validating(.number(.integer(50))).valid)
    #expect(schema.validating(.number(.integer(99))).valid)
  }

  @Test("exclusiveMaximum — Draft 2020-12 invalid (equal)")
  func exclMax202012Invalid() throws {
    let schema = try JSONSchema(
      schema: .object(["exclusiveMaximum": .number(.integer(100))])
    )
    let result = schema.validating(.number(.integer(100)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .exclusiveMaximum)
  }

  @Test("exclusiveMaximum — Draft 7 with boolean true")
  func exclMaxDraft7BoolTrue() throws {
    let schema = try JSONSchema(
      schema: .object([
        "maximum": .number(.integer(100)),
        "exclusiveMaximum": .boolean(true),
      ]), draft: .draft7
    )
    #expect(schema.validating(.number(.integer(99))).valid)
    let result = schema.validating(.number(.integer(100)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .exclusiveMaximum)
  }
}
