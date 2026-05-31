import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - typeNameOf Edge Cases

@Suite("JSONSchema typeNameOf edge cases")
struct JSONSchemaTypeNameOfEdgeCasesTests {
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
