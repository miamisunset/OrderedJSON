import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Type Validation

@Suite("JSONSchema type validation")
struct JSONSchemaTypeValidationTests {
  @Test("type string — valid")
  func typeStringValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("type string — invalid (number)")
  func typeStringInvalid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    let result = schema.validating(.number(.integer(42)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "type")
  }

  @Test("type integer — valid")
  func typeIntegerValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("integer")]))
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("type integer — invalid (float)")
  func typeIntegerInvalid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("integer")]))
    let result = schema.validating(.number(.float(42.5)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "type")
  }

  @Test("type number — accepts integer")
  func typeNumberAcceptsInteger() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("type number — accepts float")
  func typeNumberAcceptsFloat() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    #expect(schema.validating(.number(.float(3.14))).valid)
  }

  @Test("type boolean — valid")
  func typeBooleanValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("boolean")]))
    #expect(schema.validating(.boolean(true)).valid)
    #expect(schema.validating(.boolean(false)).valid)
  }

  @Test("type null — valid")
  func typeNullValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("null")]))
    #expect(schema.validating(.null).valid)
  }

  @Test("type object — valid")
  func typeObjectValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("object")]))
    #expect(schema.validating(.object(["key": .string("val")])).valid)
  }

  @Test("type array — valid")
  func typeArrayValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("array")]))
    #expect(schema.validating(.array([.number(.integer(1))])).valid)
  }

  @Test("type array of strings — valid")
  func typeArrayOfStrings() throws {
    let schema = try JSONSchema(
      schema: .object(["type": .array([.string("string"), .string("number")])])
    )
    #expect(schema.validating(.string("hello")).valid)
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("type array of strings — invalid")
  func typeArrayOfStringsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["type": .array([.string("string"), .string("number")])])
    )
    let result = schema.validating(.boolean(true))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "type")
  }
}

// MARK: - Type Edge Cases

@Suite("JSONSchema type edge cases")
struct JSONSchemaTypeValidationEdgeCasesTests {
  @Test("type — non-string non-array type value produces error")
  func typeInvalidValue() throws {
    let schema = try JSONSchema(schema: .object(["type": .number(.integer(1))]))
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "type")
    #expect(result.errors.first?.message.contains("must be a string") == true)
  }

  @Test("type — array with non-string elements skips them")
  func typeArrayNonString() throws {
    let schema = try JSONSchema(
      schema: .object(["type": .array([.string("string"), .number(.integer(42))])])
    )
    #expect(schema.validating(.string("hello")).valid)
    let result = schema.validating(.number(.integer(42)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "type")
  }

  @Test("typeNameOf — float with zero fractional part matches integer type")
  func floatZeroFractionIsInteger() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("integer")]))
    #expect(schema.validating(.number(.float(42.0))).valid)
    #expect(schema.validating(.number(.float(0.0))).valid)
    #expect(schema.validating(.number(.float(-0.0))).valid)
  }

  @Test("typeNameOf — float NaN is number type (not integer)")
  func floatNaNIsNumber() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    #expect(schema.validating(.number(.float(Double.nan))).valid)
    let intSchema = try JSONSchema(schema: .object(["type": .string("integer")]))
    #expect(!intSchema.validating(.number(.float(Double.nan))).valid)
  }

  @Test("typeNameOf — float infinity is number type (not integer)")
  func floatInfinityIsNumber() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    #expect(schema.validating(.number(.float(Double.infinity))).valid)
    let intSchema = try JSONSchema(schema: .object(["type": .string("integer")]))
    #expect(!intSchema.validating(.number(.float(Double.infinity))).valid)
  }
}
