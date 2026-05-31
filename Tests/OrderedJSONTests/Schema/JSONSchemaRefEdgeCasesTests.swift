import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - $ref Resolution Edge Cases

@Suite("JSONSchema $ref resolution edge cases")
struct JSONSchemaRefEdgeCasesTests {
  @Test("$ref — root reference without $id")
  func refRootNoId() throws {
    let schema = try JSONSchema(
      schema: .object(["$ref": .string("#"), "type": .string("string")])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("$ref — to $defs with boolean schema")
  func refDefsBoolean() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object(["alwaysFalse": .boolean(false)]),
        "$ref": .string("#/$defs/alwaysFalse"),
      ])
    )
    #expect(!schema.validating(.string("anything")).valid)
  }

  @Test("$ref — unresolvable URI without fragment")
  func refUnresolvableURI() throws {
    let schema = try JSONSchema(
      schema: .object(["$ref": .string("http://nonexistent.example/schema")])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "$ref")
  }

  @Test("$ref — deep pointer into $defs with nested properties")
  func refDeepPointer() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "obj": .object([
            "properties": .object(["nested": .object(["type": .string("string")])])
          ])
        ]),
        "$ref": .string("#/$defs/obj/properties/nested"),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }

  @Test("$ref — Draft 2020-12: $ref + sibling keywords coexist")
  func refWithSiblingKeywords202012() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object(["strType": .object(["type": .string("string")])]),
        "$ref": .string("#/$defs/strType"),
        "minLength": .number(.integer(3)),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.string("hi")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }

  @Test("$ref — Draft 7: $ref replaces subschema, sibling ignored")
  func refReplacesDraft7() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object(["strType": .object(["type": .string("string")])]),
        "$ref": .string("#/$defs/strType"),
        "minimum": .number(.integer(100)),
      ]), draft: .draft7
    )
    #expect(schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }
}
