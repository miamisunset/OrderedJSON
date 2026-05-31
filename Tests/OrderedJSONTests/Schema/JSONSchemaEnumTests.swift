import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Enum

@Suite("JSONSchema enum")
struct JSONSchemaEnumTests {
  @Test("enum — valid match")
  func enumValid() throws {
    let schema = try JSONSchema(
      schema: .object(["enum": .array([.string("a"), .string("b")])])
    )
    #expect(schema.validating(.string("a")).valid)
    #expect(schema.validating(.string("b")).valid)
  }

  @Test("enum — invalid no match")
  func enumInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["enum": .array([.string("a"), .string("b")])])
    )
    let result = schema.validating(.string("c"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "enum")
  }

  @Test("enum — string values match")
  func enumStringValues() throws {
    let schema = try JSONSchema(
      schema: .object(["enum": .array([.string("hello")])])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("enum — empty array never matches")
  func enumEmptyArray() throws {
    let schema = try JSONSchema(schema: .object(["enum": .array([])]))
    let result = schema.validating(.string("anything"))
    #expect(!result.valid)
  }

  @Test("enum — integer 1 matches float 1.0 (spec: equal)")
  func enumIntFloatEquality() throws {
    let schema = try JSONSchema(
      schema: .object(["enum": .array([.number(.float(1.0))])])
    )
    #expect(schema.validating(.number(.integer(1))).valid)
  }

  @Test("enum — array with integer 1 matches float 1.0")
  func enumArrayIntFloat() throws {
    let schema = try JSONSchema(
      schema: .object(["enum": .array([.array([.number(.float(1.0))])])])
    )
    #expect(schema.validating(.array([.number(.integer(1))])).valid)
  }

  @Test("enum — object key order is ignored")
  func enumObjectKeyOrder() throws {
    let schema = try JSONSchema(
      schema: .object([
        "enum": .array([.object(["a": .number(.integer(1)), "b": .number(.integer(2))])])
      ])
    )
    let doc: JSON = .object(["b": .number(.integer(2)), "a": .number(.integer(1))])
    #expect(schema.validating(doc).valid)
  }
}
