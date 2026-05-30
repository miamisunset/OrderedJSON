import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Phase 6 Edge Case Suites

@Suite("JSONSchema Phase 6 — type edge cases")
struct JSONSchemaPhase6TypeEdgeCases {
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
}

@Suite("JSONSchema Phase 6 — boolean schema edge cases")
struct JSONSchemaPhase6BooleanEdgeCases {
  @Test("false schema in allOf — allOf fails")
  func falseInAllOf() throws {
    let schema = try JSONSchema(
      schema: .object([
        "allOf": .array([.boolean(true), .boolean(false)])
      ])
    )
    let result = schema.validating(.string("anything"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "allOf")
  }

  @Test("false schema in anyOf — anyOf fails when all false")
  func falseInAnyOf() throws {
    let schema = try JSONSchema(
      schema: .object([
        "anyOf": .array([.boolean(false), .boolean(false)])
      ])
    )
    let result = schema.validating(.string("anything"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "anyOf")
  }

  @Test("true schema in anyOf — anyOf passes with at least one true")
  func trueInAnyOf() throws {
    let schema = try JSONSchema(
      schema: .object([
        "anyOf": .array([.boolean(false), .boolean(true)])
      ])
    )
    #expect(schema.validating(.string("anything")).valid)
  }

  @Test("oneOf — two true boolean schemas fail (not exactly one)")
  func oneOfTwoTrueBooleans() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([.boolean(true), .boolean(true)])
      ])
    )
    let result = schema.validating(.string("anything"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "oneOf")
    #expect(result.errors.first?.message.contains("2") == true)
  }

  @Test("oneOf — one true boolean schema passes")
  func oneOfOneTrueBoolean() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([.boolean(false), .boolean(true)])
      ])
    )
    #expect(schema.validating(.string("anything")).valid)
  }
}

@Suite("JSONSchema Phase 6 — if/then/else edge cases")
struct JSONSchemaPhase6IfThenElseEdgeCases {
  @Test("if/then — boolean false then fails when if passes")
  func ifThenBooleanFalse() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "then": .boolean(false),
      ])
    )
    #expect(!schema.validating(.string("hello")).valid)
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("if/else — boolean false else fails when if fails")
  func ifElseBooleanFalse() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "else": .boolean(false),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }

  @Test("if alone with boolean if schema")
  func ifBooleanSchema() throws {
    let schema = try JSONSchema(schema: .object(["if": .boolean(false)]))
    #expect(schema.validating(.string("anything")).valid)
  }

  @Test("if/then — if is true boolean, then is always checked")
  func ifTrueThenChecked() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .boolean(true),
        "then": .object(["type": .string("number")]),
      ])
    )
    #expect(schema.validating(.number(.integer(42))).valid)
    #expect(!schema.validating(.string("hello")).valid)
  }
}

@Suite("JSONSchema Phase 6 — uniqueItems edge cases")
struct JSONSchemaPhase6UniqueItemsEdgeCases {
  @Test("uniqueItems — objects with same key-value pairs are duplicates")
  func uniqueItemsDuplicateObjects() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    let result = schema.validating(
      .array([
        .object(["a": .number(.integer(1))]),
        .object(["a": .number(.integer(1))]),
      ])
    )
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "uniqueItems")
  }

  @Test("uniqueItems — arrays with same elements are duplicates")
  func uniqueItemsDuplicateArrays() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    let result = schema.validating(
      .array([
        .array([.number(.integer(1)), .number(.integer(2))]),
        .array([.number(.integer(1)), .number(.integer(2))]),
      ])
    )
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "uniqueItems")
  }

  @Test("uniqueItems — nested structures with same content")
  func uniqueItemsNestedDuplicates() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    let result = schema.validating(
      .array([
        .object(["inner": .array([.number(.integer(1))])]),
        .object(["inner": .array([.number(.integer(1))])]),
      ])
    )
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "uniqueItems")
  }

  @Test("uniqueItems — empty array trivially passes")
  func uniqueItemsEmptyArray() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    #expect(schema.validating(.array([])).valid)
  }

  @Test("uniqueItems — single element trivially passes")
  func uniqueItemsSingleElement() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    #expect(schema.validating(.array([.string("a")])).valid)
  }
}

@Suite("JSONSchema Phase 6 — format edge cases")
struct JSONSchemaPhase6FormatEdgeCases {
  @Test("format — date invalid day combinations")
  func formatDateInvalidDays() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("date")]), draft: .draft7
    )
    #expect(!schema.validating(.string("2025-02-30")).valid)
    #expect(!schema.validating(.string("2025-04-31")).valid)
    #expect(!schema.validating(.string("2025-02-29")).valid)
    #expect(schema.validating(.string("2024-02-29")).valid)
  }

  @Test("format — time invalid values")
  func formatTimeInvalidValues() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("time")]), draft: .draft7
    )
    #expect(!schema.validating(.string("24:00:00")).valid)
    #expect(!schema.validating(.string("12:60:00")).valid)
    #expect(!schema.validating(.string("12:00:60")).valid)
  }

  @Test("format — uuid with missing dashes")
  func formatUUIDMissingDashes() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("uuid")]), draft: .draft7
    )
    #expect(!schema.validating(.string("f47ac10b58cc4372a5670e02b2c3d479")).valid)
  }

  @Test("format — ipv4 with leading zeros")
  func formatIPv4LeadingZeros() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("ipv4")]), draft: .draft7
    )
    #expect(schema.validating(.string("192.168.001.001")).valid)
  }

  @Test("format — date-time with fractional seconds no timezone")
  func formatDateTimeFractionalNoTZ() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("date-time")]), draft: .draft7
    )
    #expect(!schema.validating(.string("2025-01-01T12:00:00.123")).valid)
  }
}

@Suite("JSONSchema Phase 6 — $ref resolution edge cases")
struct JSONSchemaPhase6RefEdgeCases {
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

@Suite("JSONSchema Phase 6 — $dynamicRef edge cases")
struct JSONSchemaPhase6DynamicRefEdgeCases {
  @Test("$dynamicRef — no fragment behaves like $ref")
  func dynamicRefNoFragment() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object(["strType": .object(["type": .string("string")])]),
        "$dynamicRef": .string("#/$defs/strType"),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }
}

@Suite("JSONSchema Phase 6 — minContains / maxContains edge cases")
struct JSONSchemaPhase6MinMaxContainsEdgeCases {
  @Test("minContains — valid when enough matches")
  func minContainsValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "minContains": .number(.integer(2)),
      ])
    )
    #expect(schema.validating(.array([.string("a"), .string("b"), .number(.integer(1))])).valid)
  }

  @Test("minContains — invalid when not enough matches")
  func minContainsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "minContains": .number(.integer(2)),
      ])
    )
    let result = schema.validating(.array([.string("a"), .number(.integer(1))]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "minContains")
  }

  @Test("maxContains — valid when within limit")
  func maxContainsValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "maxContains": .number(.integer(2)),
      ])
    )
    #expect(schema.validating(.array([.string("a"), .string("b")])).valid)
  }

  @Test("maxContains — invalid when too many matches")
  func maxContainsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "maxContains": .number(.integer(1)),
      ])
    )
    let result = schema.validating(.array([.string("a"), .string("b")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "maxContains")
  }

  @Test("minContains 0 — no constraint (per spec)")
  func minContainsZero() throws {
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "minContains": .number(.integer(0)),
      ])
    )
    #expect(schema.validating(.array([.number(.integer(1)), .number(.integer(2))])).valid)
  }
}

@Suite("JSONSchema Phase 6 — multipleOf edge cases")
struct JSONSchemaPhase6MultipleOfEdgeCases {
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
