import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - MultipleOf

@Suite("JSONSchema multipleOf")
struct JSONSchemaMultipleOfTests {
  @Test("multipleOf — valid integer")
  func multipleOfIntValid() throws {
    let schema = try JSONSchema(
      schema: .object(["multipleOf": .number(.integer(3))])
    )
    #expect(schema.validating(.number(.integer(9))).valid)
    #expect(schema.validating(.number(.integer(0))).valid)
  }

  @Test("multipleOf — invalid integer")
  func multipleOfIntInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["multipleOf": .number(.integer(3))])
    )
    let result = schema.validating(.number(.integer(10)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "multipleOf")
  }

  @Test("multipleOf — valid float")
  func multipleOfFloatValid() throws {
    let schema = try JSONSchema(
      schema: .object(["multipleOf": .number(.float(1.5))])
    )
    #expect(schema.validating(.number(.float(4.5))).valid)
    #expect(schema.validating(.number(.float(0.0))).valid)
  }

  @Test("multipleOf — non-number value skips")
  func multipleOfNonNumber() throws {
    let schema = try JSONSchema(
      schema: .object(["multipleOf": .number(.integer(2))])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("multipleOf — zero or negative is ignored per spec")
  func multipleOfZeroOrNegative() throws {
    let schema = try JSONSchema(
      schema: .object(["multipleOf": .number(.integer(0))])
    )
    #expect(schema.validating(.number(.integer(5))).valid)
    let schemaNeg = try JSONSchema(
      schema: .object(["multipleOf": .number(.integer(-3))])
    )
    #expect(schemaNeg.validating(.number(.integer(6))).valid)
  }
}

// MARK: - MultipleOf Edge Cases

@Suite("JSONSchema multipleOf edge cases")
struct JSONSchemaMultipleOfEdgeCasesTests {
  @Test("multipleOf — negative divisor ignored per spec")
  func multipleOfNegativeDivisor() throws {
    let schema = try JSONSchema(schema: .object(["multipleOf": .number(.float(-2.0))]))
    #expect(schema.validating(.number(.float(3.0))).valid)
  }

  @Test("multipleOf — non-number multipleOf ignored")
  func multipleOfNonNumber() throws {
    let schema = try JSONSchema(schema: .object(["multipleOf": .string("not-a-number")]))
    #expect(schema.validating(.number(.integer(5))).valid)
  }
}
