import Foundation
import Testing

@testable import OrderedCollections
@testable import OrderedJSON

// MARK: - $ref validation tests

@Suite("JSONSchema $ref validation")
struct JSONSchemaRefTests {
  @Test("$ref — resolves $defs reference")
  func refDefs() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "name": .object(["type": .string("string")])
        ]),
        "$ref": .string("#/$defs/name"),
      ])
    )
    #expect(schema.validating(.string("Alice")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }

  @Test("$ref — resolves root reference")
  func refRoot() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "positive": .object(["minimum": .number(.integer(0))])
        ]),
        "allOf": .array([
          .object(["$ref": .string("#/$defs/positive")])
        ]),
      ])
    )
    #expect(schema.validating(.number(.integer(5))).valid)
    #expect(!schema.validating(.number(.integer(-1))).valid)
  }

  @Test("$ref — cycle detection via recursion depth")
  func refCycle() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "node": .object(["$ref": .string("#/$defs/node")])
        ]),
        "$ref": .string("#/$defs/node"),
      ])
    )
    let result = schema.validating(.string("anything"))
    #expect(!result.valid)
    // Circular $ref detection fires with keyword "$ref"
    #expect(result.errors.first?.keyword == "$ref")
    #expect(result.errors.first?.message.contains("circular") == true)
  }

  @Test("$ref — nested in properties")
  func refInProperties() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "stringOrNumber": .object([
            "anyOf": .array([
              .object(["type": .string("string")]),
              .object(["type": .string("number")]),
            ])
          ])
        ]),
        "type": .string("object"),
        "properties": .object([
          "value": .object(["$ref": .string("#/$defs/stringOrNumber")])
        ]),
      ])
    )
    #expect(schema.validating(.object(["value": .string("hello")])).valid)
    #expect(schema.validating(.object(["value": .number(.integer(42))])).valid)
    #expect(!schema.validating(.object(["value": .boolean(true)])).valid)
  }

  @Test("$ref — boolean schema in $defs")
  func refBooleanDefs() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "alwaysFalse": .boolean(false)
        ]),
        "$ref": .string("#/$defs/alwaysFalse"),
      ])
    )
    #expect(!schema.validating(.string("anything")).valid)
  }

  @Test("$ref — non-existent ref fails validation")
  func refMissing() throws {
    let schema = try JSONSchema(
      schema: .object(["$ref": .string("#/$defs/nonexistent")])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "$ref")
  }
}
