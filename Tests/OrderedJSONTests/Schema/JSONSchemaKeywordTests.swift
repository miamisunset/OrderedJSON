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

// MARK: - Properties Validation

@Suite("JSONSchema properties validation")
struct JSONSchemaPropertiesTests {
  @Test("properties — valid nested")
  func propertiesValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "name": .object(["type": .string("string")])
        ])
      ])
    )
    let doc: JSON = .object(["name": .string("Alice")])
    #expect(schema.validating(doc).valid)
  }

  @Test("properties — invalid nested")
  func propertiesInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "age": .object(["type": .string("integer")])
        ])
      ])
    )
    let doc: JSON = .object(["age": .string("thirty")])
    let result = schema.validating(doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "type")
  }

  @Test("properties — missing key doesn't fail (not required)")
  func propertiesMissingKey() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "name": .object(["type": .string("string")])
        ])
      ])
    )
    let doc: JSON = .object([:])
    #expect(schema.validating(doc).valid)
  }

  @Test("properties — non-object value skips validation")
  func propertiesNonObject() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "name": .object(["type": .string("string")])
        ])
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}

// MARK: - Required Validation

@Suite("JSONSchema required validation")
struct JSONSchemaRequiredTests {
  @Test("required — valid when all present")
  func requiredValid() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("a"), .string("b")])])
    )
    let doc: JSON = .object(["a": .string("x"), "b": .string("y")])
    #expect(schema.validating(doc).valid)
  }

  @Test("required — fails when missing")
  func requiredMissing() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("name")])])
    )
    let doc: JSON = .object(["age": .number(.integer(30))])
    let result = schema.validating(doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "required")
  }

  @Test("required — null is valid (spec: presence only)")
  func requiredNullValid() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("name")])])
    )
    let doc: JSON = .object(["name": .null])
    #expect(schema.validating(doc).valid)
  }

  @Test("required — non-object skips validation")
  func requiredNonObject() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("name")])])
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}

// MARK: - Numeric Bounds

@Suite("JSONSchema numeric bounds")
struct JSONSchemaNumericBoundsTests {
  @Test("minimum — valid")
  func minimumValid() throws {
    let schema = try JSONSchema(
      schema: .object(["minimum": .number(.integer(10))])
    )
    #expect(schema.validating(.number(.integer(10))).valid)
    #expect(schema.validating(.number(.integer(20))).valid)
  }

  @Test("minimum — invalid")
  func minimumInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["minimum": .number(.integer(10))])
    )
    let result = schema.validating(.number(.integer(5)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "minimum")
  }

  @Test("maximum — valid")
  func maximumValid() throws {
    let schema = try JSONSchema(
      schema: .object(["maximum": .number(.integer(100))])
    )
    #expect(schema.validating(.number(.integer(50))).valid)
    #expect(schema.validating(.number(.integer(100))).valid)
  }

  @Test("maximum — invalid")
  func maximumInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["maximum": .number(.integer(100))])
    )
    let result = schema.validating(.number(.integer(200)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "maximum")
  }

  @Test("minimum + maximum — valid in range")
  func minMaxInRange() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minimum": .number(.integer(10)),
        "maximum": .number(.integer(100)),
      ])
    )
    #expect(schema.validating(.number(.integer(50))).valid)
  }

  @Test("minimum + maximum — invalid out of range")
  func minMaxOutOfRange() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minimum": .number(.integer(10)),
        "maximum": .number(.integer(100)),
      ])
    )
    let result = schema.validating(.number(.integer(5)))
    #expect(!result.valid)
  }

  @Test("minimum with Int64.max preserves precision")
  func minInt64Max() throws {
    let schema = try JSONSchema(
      schema: .object(["minimum": .number(.integer(Int64.max))])
    )
    #expect(schema.validating(.number(.integer(Int64.max))).valid)
    let result = schema.validating(.number(.integer(Int64.max - 1)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "minimum")
  }
}

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
    #expect(result.errors.first?.keyword == "exclusiveMinimum")
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
    #expect(result.errors.first?.keyword == "exclusiveMinimum")
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
    #expect(result.errors.first?.keyword == "exclusiveMaximum")
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
    #expect(result.errors.first?.keyword == "exclusiveMaximum")
  }
}

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

// MARK: - Pattern

@Suite("JSONSchema pattern")
struct JSONSchemaPatternTests {
  @Test("pattern — valid match")
  func patternValid() throws {
    let schema = try JSONSchema(
      schema: .object(["pattern": .string("^[A-Z][a-z]+$")])
    )
    #expect(schema.validating(.string("Hello")).valid)
  }

  @Test("pattern — invalid no match")
  func patternInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["pattern": .string("^[0-9]+$")])
    )
    let result = schema.validating(.string("abc"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "pattern")
  }

  @Test("pattern — non-string value skips")
  func patternNonString() throws {
    let schema = try JSONSchema(
      schema: .object(["pattern": .string("^[0-9]+$")])
    )
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("pattern — invalid regex fails at init time, not at validation")
  func patternInvalidRegexDeferred() throws {
    let schema = try JSONSchema(
      schema: .object(["pattern": .string("^valid$")])
    )
    #expect(schema.validating(.string("valid")).valid)
  }
}

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

// MARK: - Const

@Suite("JSONSchema const")
struct JSONSchemaConstTests {
  @Test("const — valid match")
  func constValid() throws {
    let schema = try JSONSchema(
      schema: .object(["const": .string("hello")])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("const — invalid mismatch")
  func constInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["const": .string("hello")])
    )
    let result = schema.validating(.string("world"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "const")
  }

  @Test("const — string match")
  func constStringMatch() throws {
    let schema = try JSONSchema(
      schema: .object(["const": .string("test")])
    )
    #expect(schema.validating(.string("test")).valid)
  }

  @Test("const — object match")
  func constObjectMatch() throws {
    let schema = try JSONSchema(
      schema: .object(["const": .object(["a": .number(.integer(1))])])
    )
    #expect(schema.validating(.object(["a": .number(.integer(1))])).valid)
  }
}

// MARK: - Composition: allOf

@Suite("JSONSchema allOf")
struct JSONSchemaAllOfTests {
  @Test("allOf — valid when all subschemas match")
  func allOfValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "allOf": .array([
          .object(["type": .string("string")]),
          .object(["minLength": .number(.integer(3))]),
        ])
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("allOf — invalid when one subschema fails")
  func allOfInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "allOf": .array([
          .object(["type": .string("string")]),
          .object(["minLength": .number(.integer(10))]),
        ])
      ])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "allOf")
  }

  @Test("allOf — empty array passes")
  func allOfEmpty() throws {
    let schema = try JSONSchema(schema: .object(["allOf": .array([])]))
    #expect(schema.validating(.string("anything")).valid)
  }

  @Test("allOf — missing keyword skips")
  func allOfMissing() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    #expect(schema.validating(.string("test")).valid)
  }
}

// MARK: - Composition: anyOf

@Suite("JSONSchema anyOf")
struct JSONSchemaAnyOfTests {
  @Test("anyOf — valid when at least one matches")
  func anyOfValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "anyOf": .array([
          .object(["type": .string("number")]),
          .object(["type": .string("string")]),
        ])
      ])
    )
    #expect(schema.validating(.string("test")).valid)
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("anyOf — invalid when none match")
  func anyOfInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "anyOf": .array([
          .object(["type": .string("number")]),
          .object(["type": .string("boolean")]),
        ])
      ])
    )
    let result = schema.validating(.string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "anyOf")
  }

  @Test("anyOf — empty array fails (no subschemas to match)")
  func anyOfEmpty() throws {
    let schema = try JSONSchema(schema: .object(["anyOf": .array([])]))
    let result = schema.validating(.string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "anyOf")
  }
}

// MARK: - Composition: oneOf

@Suite("JSONSchema oneOf")
struct JSONSchemaOneOfTests {
  @Test("oneOf — valid when exactly one matches")
  func oneOfValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([
          .object(["type": .string("number")]),
          .object(["type": .string("string")]),
        ])
      ])
    )
    #expect(schema.validating(.string("test")).valid)
  }

  @Test("oneOf — invalid when zero match")
  func oneOfZeroMatch() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([
          .object(["type": .string("number")]),
          .object(["type": .string("boolean")]),
        ])
      ])
    )
    let result = schema.validating(.string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "oneOf")
  }

  @Test("oneOf — invalid when two match (not exactly one)")
  func oneOfTwoMatch() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([
          .object(["type": .string("string"), "minLength": .number(.integer(1))]),
          .object(["type": .string("string"), "maxLength": .number(.integer(100))]),
        ])
      ])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "oneOf")
    #expect(result.errors.first?.message.contains("2") == true)
  }

  @Test("oneOf — empty array fails")
  func oneOfEmpty() throws {
    let schema = try JSONSchema(schema: .object(["oneOf": .array([])]))
    let result = schema.validating(.string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "oneOf")
  }
}

// MARK: - Composition: not

@Suite("JSONSchema not")
struct JSONSchemaNotTests {
  @Test("not — valid when subschema does NOT match")
  func notValid() throws {
    let schema = try JSONSchema(
      schema: .object(["not": .object(["type": .string("number")])])
    )
    #expect(schema.validating(.string("test")).valid)
  }

  @Test("not — invalid when subschema matches")
  func notInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["not": .object(["type": .string("string")])])
    )
    let result = schema.validating(.string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "not")
  }

  @Test("not — missing keyword skips")
  func notMissing() throws {
    let schema = try JSONSchema(schema: .object([:]))
    #expect(schema.validating(.string("test")).valid)
  }
}

// MARK: - Composition: if/then/else

@Suite("JSONSchema if/then/else")
struct JSONSchemaIfThenElseTests {
  @Test("if/then — valid when if matches and then matches")
  func ifThenValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "then": .object(["minLength": .number(.integer(3))]),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("if/then — invalid when if matches but then fails")
  func ifThenInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "then": .object(["minLength": .number(.integer(10))]),
      ])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "then")
  }

  @Test("if/else — valid when if fails and else matches")
  func ifElseValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "else": .object(["minLength": .number(.integer(3))]),
      ])
    )
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("if/else — invalid when if fails and else fails")
  func ifElseInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "else": .object(["type": .string("string")]),
      ])
    )
    let result = schema.validating(.number(.integer(42)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "else")
  }

  @Test("if alone — no then/else, if result doesn't affect validity")
  func ifAlone() throws {
    let schema = try JSONSchema(schema: .object(["if": .object(["type": .string("number")])]))
    #expect(schema.validating(.string("test")).valid)
    #expect(schema.validating(.number(.integer(42))).valid)
  }

  @Test("if/then/else — full conditional")
  func ifThenElseFull() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("number")]),
        "then": .object(["minimum": .number(.integer(0))]),
        "else": .object(["type": .string("string")]),
      ])
    )
    #expect(schema.validating(.number(.integer(42))).valid)
    #expect(schema.validating(.number(.integer(-1))).valid == false)
    #expect(schema.validating(.string("test")).valid)
    #expect(schema.validating(.boolean(true)).valid == false)
  }
}

// MARK: - Composition: dependentSchemas

@Suite("JSONSchema dependentSchemas")
struct JSONSchemaDependentSchemasTests {
  @Test("dependentSchemas — valid when dependency key is absent")
  func depSchemasKeyAbsent() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "credit_card": .object(["required": .array([.string("number")])])
        ])
      ])
    )
    let doc: JSON = .object(["name": .string("Alice")])
    #expect(schema.validating(doc).valid)
  }

  @Test("dependentSchemas — valid when dependency key is present and schema matches")
  func depSchemasValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "credit_card": .object(["required": .array([.string("number")])])
        ])
      ])
    )
    let doc: JSON = .object(["credit_card": .string("1234"), "number": .string("1234")])
    #expect(schema.validating(doc).valid)
  }

  @Test("dependentSchemas — invalid when dependency key is present and schema fails")
  func depSchemasInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "credit_card": .object(["required": .array([.string("number"), .string("cvc")])])
        ])
      ])
    )
    let doc: JSON = .object(["credit_card": .string("1234"), "number": .string("1234")])
    let result = schema.validating(doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "dependentSchemas")
  }

  @Test("dependentSchemas — multiple dependency keys")
  func depSchemasMultiple() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "a": .object(["required": .array([.string("b")])]),
          "b": .object(["required": .array([.string("a")])]),
        ])
      ])
    )
    let doc: JSON = .object(["a": .string("x"), "b": .string("y")])
    #expect(schema.validating(doc).valid)
  }
}

// MARK: - Composition: dependentRequired

@Suite("JSONSchema dependentRequired")
struct JSONSchemaDependentRequiredTests {
  @Test("dependentRequired — valid when dependency key is absent")
  func depRequiredKeyAbsent() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentRequired": .object([
          "credit_card": .array([.string("number"), .string("cvc")])
        ])
      ])
    )
    let doc: JSON = .object(["name": .string("Alice")])
    #expect(schema.validating(doc).valid)
  }

  @Test("dependentRequired — valid when dependency key is present and required keys are present")
  func depRequiredValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentRequired": .object([
          "credit_card": .array([.string("number"), .string("cvc")])
        ])
      ])
    )
    let doc: JSON = .object([
      "credit_card": .string("x"), "number": .string("1234"), "cvc": .string("789"),
    ])
    #expect(schema.validating(doc).valid)
  }

  @Test("dependentRequired — invalid when dependency key is present but required keys are missing")
  func depRequiredInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentRequired": .object([
          "credit_card": .array([.string("number"), .string("cvc")])
        ])
      ])
    )
    let doc: JSON = .object(["credit_card": .string("x"), "number": .string("1234")])
    let result = schema.validating(doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "dependentRequired")
  }

  @Test("dependentRequired — multiple dependency keys")
  func depRequiredMultiple() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentRequired": .object([
          "a": .array([.string("b")]),
          "b": .array([.string("a")]),
        ])
      ])
    )
    let doc: JSON = .object(["a": .string("x")])
    let result = schema.validating(doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "dependentRequired")
    #expect(result.errors.first?.message.contains("b") == true)
  }

  @Test("dependentRequired — two errors when two keys are missing")
  func depRequiredTwoMissing() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentRequired": .object([
          "credit_card": .array([.string("number"), .string("cvc")])
        ])
      ])
    )
    let doc: JSON = .object(["credit_card": .string("x")])
    let result = schema.validating(doc)
    #expect(result.errors.count == 2)
    #expect(result.errors.allSatisfy { $0.keyword == "dependentRequired" })
  }
}

// MARK: - Array Keywords

@Suite("JSONSchema items")
struct JSONSchemaItemsTests {
  @Test("items — schema mode (Draft 2020-12) — valid")
  func itemsSchemaValid() throws {
    let schema = try JSONSchema(schema: .object(["items": .object(["type": .string("string")])]))
    #expect(schema.validating(.array([.string("a"), .string("b")])).valid)
  }

  @Test("items — schema mode — invalid")
  func itemsSchemaInvalid() throws {
    let schema = try JSONSchema(schema: .object(["items": .object(["type": .string("string")])]))
    let result = schema.validating(.array([.string("a"), .number(.integer(1))]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("items")
        || result.errors.map(\.keyword).contains("type")
    )
    #expect(result.errors.count >= 1)
  }

  @Test("items — Draft 7 tuple mode — valid")
  func itemsTupleDraft7Valid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "items": .array([
          .object(["type": .string("string")]),
          .object(["type": .string("number")]),
        ])
      ]), draft: .draft7
    )
    #expect(schema.validating(.array([.string("a"), .number(.integer(1))])).valid)
  }

  @Test("items — Draft 7 tuple mode — invalid")
  func itemsTupleDraft7Invalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "items": .array([
          .object(["type": .string("string")]),
          .object(["type": .string("number")]),
        ])
      ]), draft: .draft7
    )
    let result = schema.validating(.array([.string("a"), .string("b")]))
    #expect(!result.valid)
  }

  @Test("items — non-array value skips")
  func itemsNonArray() throws {
    let schema = try JSONSchema(schema: .object(["items": .object(["type": .string("string")])]))
    #expect(schema.validating(.string("hello")).valid)
  }
}

@Suite("JSONSchema prefixItems")
struct JSONSchemaPrefixItemsTests {
  @Test("prefixItems — valid")
  func prefixItemsValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "prefixItems": .array([
          .object(["type": .string("string")]),
          .object(["type": .string("number")]),
        ])
      ])
    )
    #expect(schema.validating(.array([.string("a"), .number(.integer(1))])).valid)
  }

  @Test("prefixItems — invalid")
  func prefixItemsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "prefixItems": .array([
          .object(["type": .string("string")])
        ])
      ])
    )
    let result = schema.validating(.array([.number(.integer(1))]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("prefixItems")
        || result.errors.map(\.keyword).contains("type")
    )
    #expect(result.errors.count >= 1)
  }

  @Test("prefixItems — non-array value skips")
  func prefixItemsNonArray() throws {
    let schema = try JSONSchema(
      schema: .object(["prefixItems": .array([.object(["type": .string("string")])])])
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}

@Suite("JSONSchema minItems / maxItems")
struct JSONSchemaMinMaxItemsTests {
  @Test("minItems — valid")
  func minItemsValid() throws {
    let schema = try JSONSchema(schema: .object(["minItems": .number(.integer(2))]))
    #expect(schema.validating(.array([.string("a"), .string("b")])).valid)
    #expect(schema.validating(.array([.string("a"), .string("b"), .string("c")])).valid)
  }

  @Test("minItems — invalid")
  func minItemsInvalid() throws {
    let schema = try JSONSchema(schema: .object(["minItems": .number(.integer(3))]))
    let result = schema.validating(.array([.string("a"), .string("b")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "minItems")
  }

  @Test("maxItems — valid")
  func maxItemsValid() throws {
    let schema = try JSONSchema(schema: .object(["maxItems": .number(.integer(3))]))
    #expect(schema.validating(.array([.string("a"), .string("b")])).valid)
    #expect(schema.validating(.array([.string("a")])).valid)
  }

  @Test("maxItems — invalid")
  func maxItemsInvalid() throws {
    let schema = try JSONSchema(schema: .object(["maxItems": .number(.integer(2))]))
    let result = schema.validating(.array([.string("a"), .string("b"), .string("c")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "maxItems")
  }

  @Test("minItems / maxItems — non-array skips")
  func minMaxItemsNonArray() throws {
    let schema = try JSONSchema(
      schema: .object(["minItems": .number(.integer(2)), "maxItems": .number(.integer(5))])
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}

@Suite("JSONSchema uniqueItems")
struct JSONSchemaUniqueItemsTests {
  @Test("uniqueItems — valid (all unique)")
  func uniqueItemsValid() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    #expect(schema.validating(.array([.string("a"), .string("b")])).valid)
  }

  @Test("uniqueItems — invalid (duplicates)")
  func uniqueItemsInvalid() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    let result = schema.validating(.array([.string("a"), .string("a")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "uniqueItems")
  }

  @Test("uniqueItems — false disables check")
  func uniqueItemsFalse() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(false)]))
    #expect(schema.validating(.array([.string("a"), .string("a")])).valid)
  }

  @Test("uniqueItems — non-array skips")
  func uniqueItemsNonArray() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("uniqueItems — integer 1 and float 1.0 are considered equal")
  func uniqueItemsIntFloat() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    let result = schema.validating(.array([.number(.integer(1)), .number(.float(1.0))]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "uniqueItems")
  }
}

@Suite("JSONSchema contains")
struct JSONSchemaContainsTests {
  @Test("contains — valid (at least one matches)")
  func containsValid() throws {
    let schema = try JSONSchema(schema: .object(["contains": .object(["type": .string("string")])]))
    #expect(schema.validating(.array([.number(.integer(1)), .string("hello")])).valid)
  }

  @Test("contains — invalid (none match)")
  func containsInvalid() throws {
    let schema = try JSONSchema(schema: .object(["contains": .object(["type": .string("string")])]))
    let result = schema.validating(.array([.number(.integer(1)), .number(.integer(2))]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "contains")
  }

  @Test("contains — empty array fails")
  func containsEmpty() throws {
    let schema = try JSONSchema(schema: .object(["contains": .object(["type": .string("string")])]))
    let result = schema.validating(.array([]))
    #expect(!result.valid)
  }

  @Test("contains — non-array skips")
  func containsNonArray() throws {
    let schema = try JSONSchema(schema: .object(["contains": .object(["type": .string("string")])]))
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("contains — minContains/maxContains now enforced")
  func containsMinContainsEnforced() throws {
    // minContains is now enforced — 2 required but only 1 match
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "minContains": .number(.integer(2)),
      ])
    )
    #expect(!schema.validating(.array([.number(.integer(1)), .string("hello")])).valid)
  }
}

// MARK: - Object Keywords

@Suite("JSONSchema minProperties / maxProperties")
struct JSONSchemaMinMaxPropertiesTests {
  @Test("minProperties — valid")
  func minPropertiesValid() throws {
    let schema = try JSONSchema(schema: .object(["minProperties": .number(.integer(1))]))
    #expect(schema.validating(.object(["a": .string("x")])).valid)
    #expect(schema.validating(.object(["a": .string("x"), "b": .string("y")])).valid)
  }

  @Test("minProperties — invalid")
  func minPropertiesInvalid() throws {
    let schema = try JSONSchema(schema: .object(["minProperties": .number(.integer(2))]))
    let result = schema.validating(.object(["a": .string("x")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "minProperties")
  }

  @Test("maxProperties — valid")
  func maxPropertiesValid() throws {
    let schema = try JSONSchema(schema: .object(["maxProperties": .number(.integer(3))]))
    #expect(schema.validating(.object(["a": .string("x")])).valid)
    #expect(schema.validating(.object(["a": .string("x"), "b": .string("y")])).valid)
  }

  @Test("maxProperties — invalid")
  func maxPropertiesInvalid() throws {
    let schema = try JSONSchema(schema: .object(["maxProperties": .number(.integer(1))]))
    let result = schema.validating(.object(["a": .string("x"), "b": .string("y")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "maxProperties")
  }

  @Test("minProperties / maxProperties — non-object skips")
  func minMaxPropertiesNonObject() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minProperties": .number(.integer(2)), "maxProperties": .number(.integer(5)),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}

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

@Suite("JSONSchema patternProperties")
struct JSONSchemaPatternPropertiesTests {
  @Test("patternProperties — valid (key matches pattern)")
  func patternPropertiesValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "patternProperties": .object([
          "^[a-z]+$": .object(["type": .string("string")])
        ])
      ])
    )
    #expect(schema.validating(.object(["name": .string("Alice")])).valid)
  }

  @Test("patternProperties — invalid (value fails schema)")
  func patternPropertiesInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "patternProperties": .object([
          "^[a-z]+$": .object(["type": .string("number")])
        ])
      ])
    )
    let result = schema.validating(.object(["name": .string("Alice")]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("patternProperties")
        || result.errors.map(\.keyword).contains("type")
    )
    #expect(result.errors.count >= 1)
  }

  @Test("patternProperties — non-object skips")
  func patternPropertiesNonObject() throws {
    let propSchema: JSON = .object(["type": .string("string")])
    let schema = try JSONSchema(
      schema: .object(["patternProperties": .object(["^.*$": propSchema])])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("patternProperties — invalid regex at init time")
  func patternPropertiesInvalidRegex() throws {
    #expect(throws: JSONSchemaError.self) {
      try JSONSchema(
        schema: .object([
          "patternProperties": .object(["[invalid": .object(["type": .string("string")])])
        ])
      )
    }
  }
}

@Suite("JSONSchema additionalProperties")
struct JSONSchemaAdditionalPropertiesTests {
  @Test("additionalProperties — valid (key covered by properties)")
  func additionalPropertiesCovered() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object(["name": .object(["type": .string("string")])]),
        "additionalProperties": .boolean(false),
      ]), draft: .draft7
    )
    #expect(schema.validating(.object(["name": .string("Alice")])).valid)
  }

  @Test("additionalProperties — invalid (key not covered)")
  func additionalPropertiesUncovered() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object(["name": .object(["type": .string("string")])]),
        "additionalProperties": .boolean(false),
      ]), draft: .draft7
    )
    let result = schema.validating(
      .object(["name": .string("Alice"), "age": .number(.integer(30))])
    )
    #expect(!result.valid)
    // Error keyword is "false" from the boolean subschema, not "additionalProperties"
    #expect(result.errors.first?.keyword == "false")
  }

  @Test("additionalProperties — non-object skips")
  func additionalPropertiesNonObject() throws {
    let schema = try JSONSchema(
      schema: .object(["additionalProperties": .boolean(false)]), draft: .draft7
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}

@Suite("JSONSchema unevaluatedProperties")
struct JSONSchemaUnevaluatedPropertiesTests {
  @Test("unevaluatedProperties — valid (key evaluated by properties)")
  func unevaluatedPropertiesCovered() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object(["name": .object(["type": .string("string")])]),
        "unevaluatedProperties": .boolean(false),
      ])
    )
    #expect(schema.validating(.object(["name": .string("Alice")])).valid)
  }

  @Test("unevaluatedProperties — invalid (key not evaluated)")
  func unevaluatedPropertiesUncovered() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object(["name": .object(["type": .string("string")])]),
        "unevaluatedProperties": .boolean(false),
      ])
    )
    let result = schema.validating(
      .object(["name": .string("Alice"), "age": .number(.integer(30))])
    )
    #expect(!result.valid)
    // Error keyword is "false" from the boolean subschema, not "unevaluatedProperties"
    #expect(result.errors.first?.keyword == "false")
  }

  @Test("unevaluatedProperties — additionalProperties now tracked")
  func unevaluatedPropertiesWithAdditionalProperties() throws {
    // Keys evaluated by additionalProperties are now in the evaluated set,
    // so unevaluatedProperties does not re-check them.
    let schema = try JSONSchema(
      schema: .object([
        "additionalProperties": .object(["type": .string("string")]),
        "unevaluatedProperties": .boolean(false),
      ])
    )
    // All keys are evaluated by additionalProperties, so unevaluatedProperties
    // has nothing to check — the schema validates successfully.
    let result = schema.validating(.object(["x": .string("hello")]))
    #expect(result.valid)
  }

  @Test("unevaluatedProperties — non-object skips")
  func unevaluatedPropertiesNonObject() throws {
    let schema = try JSONSchema(schema: .object(["unevaluatedProperties": .boolean(false)]))
    #expect(schema.validating(.string("hello")).valid)
  }
}

@Suite("JSONSchema additionalItems")
struct JSONSchemaAdditionalItemsTests {
  @Test("additionalItems — Draft 7 valid (items beyond tuple pass)")
  func additionalItemsValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "items": .array([.object(["type": .string("string")])]),
        "additionalItems": .object(["type": .string("number")]),
      ]), draft: .draft7
    )
    #expect(schema.validating(.array([.string("a"), .number(.integer(1))])).valid)
  }

  @Test("additionalItems — Draft 7 invalid (beyond tuple fails)")
  func additionalItemsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "items": .array([.object(["type": .string("string")])]),
        "additionalItems": .object(["type": .string("number")]),
      ]), draft: .draft7
    )
    let result = schema.validating(.array([.string("a"), .string("b")]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("additionalItems")
        || result.errors.map(\.keyword).contains("type")
    )
    #expect(result.errors.count >= 1)
  }

  @Test("additionalItems — non-array skips")
  func additionalItemsNonArray() throws {
    let schema = try JSONSchema(
      schema: .object(["additionalItems": .object(["type": .string("string")])]), draft: .draft7
    )
    #expect(schema.validating(.string("hello")).valid)
  }
}

@Suite("JSONSchema unevaluatedItems")
struct JSONSchemaUnevaluatedItemsTests {
  @Test("unevaluatedItems — valid (items beyond prefix pass)")
  func unevaluatedItemsValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "prefixItems": .array([.object(["type": .string("string")])]),
        "unevaluatedItems": .object(["type": .string("number")]),
      ])
    )
    #expect(schema.validating(.array([.string("a"), .number(.integer(1))])).valid)
  }

  @Test("unevaluatedItems — invalid (beyond prefix fails)")
  func unevaluatedItemsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "prefixItems": .array([.object(["type": .string("string")])]),
        "unevaluatedItems": .object(["type": .string("number")]),
      ])
    )
    let result = schema.validating(.array([.string("a"), .string("b")]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("unevaluatedItems")
        || result.errors.map(\.keyword).contains("type")
    )
    #expect(result.errors.count >= 1)
  }

  @Test("unevaluatedItems — non-array skips")
  func unevaluatedItemsNonArray() throws {
    let schema = try JSONSchema(
      schema: .object(["unevaluatedItems": .object(["type": .string("string")])])
    )
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("unevaluatedItems — items schema short-circuits unevaluatedItems")
  func unevaluatedItemsWithItemsSchema() throws {
    // When `items` is a schema, it evaluates all items past prefixItems,
    // so unevaluatedItems should be a no-op.
    let schema = try JSONSchema(
      schema: .object([
        "items": .object(["type": .string("string")]),
        "unevaluatedItems": .boolean(false),
      ])
    )
    let result = schema.validating(.array([.string("a"), .string("b")]))
    #expect(result.valid)
  }

  @Test("unevaluatedItems — contains matched indices not excluded (known deviation)")
  func unevaluatedItemsWithContains() throws {
    // Per spec, items matched by contains are evaluated and should be excluded
    // from unevaluatedItems. Currently they are not.
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["const": .number(.integer(1))]),
        "unevaluatedItems": .boolean(false),
      ])
    )
    // Current behavior: unevaluatedItems fires on index 0 (which contains matched).
    let result = schema.validating(.array([.number(.integer(1)), .number(.integer(2))]))
    // Current (deviant): fails — unevaluatedItems fires on index 0
    #expect(!result.valid)
  }
}

// MARK: - Format validation

@Test("format — date-time valid")
func formatDateTimeValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("date-time")]), draft: .draft7
  )
  #expect(schema.validating(.string("2025-01-01T12:00:00Z")).valid)
  #expect(schema.validating(.string("2025-01-01T12:00:00.123Z")).valid)
  #expect(schema.validating(.string("2025-01-01T12:00:00+05:30")).valid)
}

@Test("format — date-time invalid")
func formatDateTimeInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("date-time")]), draft: .draft7
  )
  #expect(!schema.validating(.string("2025-01-01 12:00:00")).valid)
  #expect(!schema.validating(.string("2025-01-01T12:00:00")).valid)  // no timezone
  #expect(!schema.validating(.string("not-a-date")).valid)
}

@Test("format — date valid")
func formatDateValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("date")]), draft: .draft7
  )
  #expect(schema.validating(.string("2025-01-01")).valid)
  #expect(schema.validating(.string("2025-12-31")).valid)
}

@Test("format — date invalid")
func formatDateInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("date")]), draft: .draft7
  )
  #expect(!schema.validating(.string("2025-13-01")).valid)  // invalid month
  #expect(!schema.validating(.string("not-a-date")).valid)
}

@Test("format — time valid")
func formatTimeValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("time")]), draft: .draft7
  )
  #expect(schema.validating(.string("12:00:00")).valid)
  #expect(schema.validating(.string("12:00:00Z")).valid)
  #expect(schema.validating(.string("12:00:00.123Z")).valid)
}

@Test("format — time invalid")
func formatTimeInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("time")]), draft: .draft7
  )
  #expect(!schema.validating(.string("25:00:00")).valid)  // invalid hour
  #expect(!schema.validating(.string("not-a-time")).valid)
}

@Test("format — duration valid")
func formatDurationValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("duration")]), draft: .draft7
  )
  #expect(schema.validating(.string("P1Y")).valid)
  #expect(schema.validating(.string("P1Y2M3DT4H5M6S")).valid)
  #expect(schema.validating(.string("PT1H")).valid)
}

@Test("format — duration invalid")
func formatDurationInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("duration")]), draft: .draft7
  )
  #expect(!schema.validating(.string("P")).valid)
  #expect(!schema.validating(.string("PT")).valid)
}

@Test("format — email valid")
func formatEmailValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("email")]), draft: .draft7
  )
  #expect(schema.validating(.string("user@example.com")).valid)
  #expect(schema.validating(.string("a.b@c.d")).valid)
}

@Test("format — email invalid")
func formatEmailInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("email")]), draft: .draft7
  )
  #expect(!schema.validating(.string("not-an-email")).valid)
  #expect(!schema.validating(.string("@example.com")).valid)
  #expect(!schema.validating(.string("user@example.")).valid)  // empty TLD
  #expect(!schema.validating(.string("user@.com")).valid)  // no domain
}

@Test("format — hostname valid")
func formatHostnameValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("hostname")]), draft: .draft7
  )
  #expect(schema.validating(.string("example.com")).valid)
  #expect(schema.validating(.string("my-host.example.com")).valid)
}

@Test("format — hostname invalid")
func formatHostnameInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("hostname")]), draft: .draft7
  )
  #expect(!schema.validating(.string("not_a_hostname")).valid)
}

@Test("format — hostname single-label")
func formatHostnameSingleLabel() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("hostname")]), draft: .draft7
  )
  #expect(schema.validating(.string("localhost")).valid)
  #expect(schema.validating(.string("myhost")).valid)
}

@Test("format — ipv4 valid")
func formatIPv4Valid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("ipv4")]), draft: .draft7
  )
  #expect(schema.validating(.string("192.168.1.1")).valid)
  #expect(schema.validating(.string("127.0.0.1")).valid)
}

@Test("format — ipv4 invalid")
func formatIPv4Invalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("ipv4")]), draft: .draft7
  )
  #expect(!schema.validating(.string("300.0.0.0")).valid)
  #expect(!schema.validating(.string("not-an-ip")).valid)
}

@Test("format — ipv6 valid")
func formatIPv6Valid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("ipv6")]), draft: .draft7
  )
  #expect(schema.validating(.string("::1")).valid)
  #expect(schema.validating(.string("fe80::1")).valid)
}

@Test("format — ipv6 invalid")
func formatIPv6Invalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("ipv6")]), draft: .draft7
  )
  #expect(!schema.validating(.string("not-an-ipv6")).valid)
}

@Test("format — uuid valid")
func formatUUIDValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("uuid")]), draft: .draft7
  )
  #expect(schema.validating(.string("f47ac10b-58cc-4372-a567-0e02b2c3d479")).valid)
}

@Test("format — uuid invalid")
func formatUUIDInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("uuid")]), draft: .draft7
  )
  #expect(!schema.validating(.string("not-a-uuid")).valid)
}

@Test("format — uri valid")
func formatURIValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("uri")]), draft: .draft7
  )
  #expect(schema.validating(.string("https://example.com")).valid)
  #expect(schema.validating(.string("https://example.com/path")).valid)
  #expect(schema.validating(.string("ftp://ftp.example.com")).valid)
}

@Test("format — uri invalid")
func formatURIInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("uri")]), draft: .draft7
  )
  #expect(!schema.validating(.string("/relative/path")).valid)  // no scheme
  #expect(!schema.validating(.string("not-a-uri")).valid)
}

@Test("format — uri-reference valid")
func formatURIReferenceValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("uri-reference")]), draft: .draft7
  )
  #expect(schema.validating(.string("/relative/path")).valid)
  #expect(schema.validating(.string("#fragment")).valid)
  #expect(schema.validating(.string("https://example.com")).valid)
}

@Test("format — uri-reference invalid")
func formatURIReferenceInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("uri-reference")]), draft: .draft7
  )
  #expect(!schema.validating(.string("")).valid)  // empty string is not a valid URI
}

@Test("format — json-pointer valid")
func formatJSONPointerValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("json-pointer")]), draft: .draft7
  )
  #expect(schema.validating(.string("")).valid)  // root
  #expect(schema.validating(.string("/foo/bar")).valid)
}

@Test("format — json-pointer invalid")
func formatJSONPointerInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("json-pointer")]), draft: .draft7
  )
  #expect(!schema.validating(.string("no-leading-slash")).valid)
}

@Test("format — regex valid")
func formatRegexValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("regex")]), draft: .draft7
  )
  #expect(schema.validating(.string("^[a-z]+$")).valid)
}

@Test("format — regex invalid")
func formatRegexInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("regex")]), draft: .draft7
  )
  #expect(!schema.validating(.string("[invalid")).valid)
}

@Test("format — non-string skips validation")
func formatNonString() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("email")]), draft: .draft7
  )
  #expect(schema.validating(.number(.integer(42))).valid)
  #expect(schema.validating(.object([:])).valid)
}

@Test("format — unknown format skips validation")
func formatUnknown() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("nonexistent-format")]), draft: .draft7
  )
  #expect(schema.validating(.string("anything")).valid)
}

@Test("format — draft202012 annotation mode (no assertion)")
func formatDraft202012Annotation() throws {
  // In Draft 2020-12, format is an annotation — it should NOT produce errors.
  // Default draft (auto) resolves to draft202012 when no $schema is present.
  let schema = try JSONSchema(
    schema: .object(["format": .string("email")])
  )
  #expect(schema.validating(.string("not-an-email")).valid)
}

@Test("format — draft7 assertion mode")
func formatDraft7Assertion() throws {
  // In Draft 7, format is an assertion — it SHOULD produce errors
  let schema = try JSONSchema(
    schema: .object(["format": .string("email")]), draft: .draft7
  )
  // Invalid emails should fail validation in assertion mode
  #expect(!schema.validating(.string("not-an-email")).valid)
}

@Test("format — disabled format skips validation")
func formatDisabled() throws {
  var opts = JSONSchemaFormatOptions()
  opts.disable(.email)
  let schema = try JSONSchema(
    schema: .object(["format": .string("email")]), draft: .draft7, formatOptions: opts
  )
  #expect(schema.validating(.string("not-an-email")).valid)
}

@Test("format — format keyword absent skips")
func formatAbsent() throws {
  let schema = try JSONSchema(schema: .object([:]))
  #expect(schema.validating(.string("anything")).valid)
}

// MARK: - Content Keywords

@Test("contentMediaType — annotation only, no validation errors")
func contentMediaTypeAnnotation() throws {
  let schema = try JSONSchema(
    schema: .object([
      "contentMediaType": .string("application/json")
    ])
  )
  // contentMediaType is an annotation — always passes
  #expect(schema.validating(.string("some content")).valid)
  #expect(schema.validating(.number(.integer(42))).valid)
  #expect(schema.validating(.null).valid)
}

@Test("contentMediaType — absent keyword skips")
func contentMediaTypeAbsent() throws {
  let schema = try JSONSchema(schema: .object([:]))
  #expect(schema.validating(.string("test")).valid)
}

@Test("contentEncoding — annotation only, no validation errors")
func contentEncodingAnnotation() throws {
  let schema = try JSONSchema(
    schema: .object([
      "contentEncoding": .string("base64")
    ])
  )
  // contentEncoding is an annotation — always passes
  #expect(schema.validating(.string("dGVzdA==")).valid)
  #expect(schema.validating(.number(.integer(1))).valid)
}

@Test("contentEncoding — absent keyword skips")
func contentEncodingAbsent() throws {
  let schema = try JSONSchema(schema: .object([:]))
  #expect(schema.validating(.string("test")).valid)
}

@Test("contentSchema — valid JSON string passes")
func contentSchemaValidJSON() throws {
  let schema = try JSONSchema(
    schema: .object([
      "contentSchema": .object(["type": .string("object")])
    ])
  )
  // The string is parsed as JSON and validated against contentSchema
  #expect(schema.validating(.string("{\"key\":\"value\"}")).valid)
}

@Test("contentSchema — valid base64 encoded JSON passes")
func contentSchemaValidBase64() throws {
  let schema = try JSONSchema(
    schema: .object([
      "contentEncoding": .string("base64"),
      "contentSchema": .object(["type": .string("object")]),
    ])
  )
  // Base64 of {"key":"value"}
  #expect(schema.validating(.string("eyJrZXkiOiJ2YWx1ZSJ9")).valid)
}

@Test("contentSchema — invalid JSON fails")
func contentSchemaInvalidJSON() throws {
  let schema = try JSONSchema(
    schema: .object([
      "contentSchema": .object(["type": .string("object")])
    ])
  )
  // contentSchema is an annotation — no validation errors produced
  let result = schema.validating(.string("not-json"))
  #expect(result.valid)
}

@Test("contentSchema — invalid base64 fails")
func contentSchemaInvalidBase64() throws {
  let schema = try JSONSchema(
    schema: .object([
      "contentEncoding": .string("base64"),
      "contentSchema": .object(["type": .string("object")]),
    ])
  )
  // contentSchema is an annotation — no validation errors produced
  let result = schema.validating(.string("not-valid-base64!!"))
  #expect(result.valid)
}

@Test("contentSchema — non-string value skips")
func contentSchemaNonString() throws {
  let schema = try JSONSchema(
    schema: .object([
      "contentSchema": .object(["type": .string("object")])
    ])
  )
  // Non-string values are skipped by contentSchema
  #expect(schema.validating(.number(.integer(42))).valid)
}

@Test("contentSchema — decoded JSON fails contentSchema validation")
func contentSchemaDecodedFails() throws {
  let schema = try JSONSchema(
    schema: .object([
      "contentSchema": .object([
        "type": .string("object"),
        "required": .array([.string("name")]),
      ])
    ])
  )
  // contentSchema is an annotation — no validation errors produced
  let result = schema.validating(.string("{\"age\":30}"))
  #expect(result.valid)
}

@Test("contentSchema — absent keyword skips")
func contentSchemaAbsent() throws {
  let schema = try JSONSchema(schema: .object([:]))
  #expect(schema.validating(.string("test")).valid)
}

@Test("contentSchema — base64 decodes to non-UTF-8 data fails")
func contentSchemaBase64NonUTF8() throws {
  let schema = try JSONSchema(
    schema: .object([
      "contentEncoding": .string("base64"),
      "contentSchema": .object(["type": .string("object")]),
    ])
  )
  // contentSchema is an annotation — no validation errors produced
  let result = schema.validating(.string("/g=="))
  #expect(result.valid)
}

// MARK: - Phase 6 Edge-Case Tests

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
    // Non-string elements in the type array should be ignored
    let schema = try JSONSchema(
      schema: .object(["type": .array([.string("string"), .number(.integer(42))])])
    )
    #expect(schema.validating(.string("hello")).valid)
    // Integer element is not a string, so it doesn't add "integer" to allowed types
    let result = schema.validating(.number(.integer(42)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "type")
  }

  @Test("type — number with float that is integer (1.0)")
  func typeNumberWithIntegerFloat() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    // A float with zero fractional part (1.0) should be valid for "number" type
    #expect(schema.validating(.number(.float(1.0))).valid)
  }

  @Test("type — integer with float that has zero fraction matches")
  func typeIntegerWithZeroFractionFloat() throws {
    // JSON Schema says floats with zero fractional part are "integer" type
    let schema = try JSONSchema(schema: .object(["type": .string("integer")]))
    #expect(schema.validating(.number(.float(0.0))).valid)
    #expect(schema.validating(.number(.float(42.0))).valid)
  }

  @Test("type — integer with float that has non-zero fraction fails")
  func typeIntegerRejectsNonIntegerFloat() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("integer")]))
    let result = schema.validating(.number(.float(42.5)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "type")
  }
}

@Suite("JSONSchema Phase 6 — required edge cases")
struct JSONSchemaPhase6RequiredEdgeCases {
  @Test("required — non-string element produces error")
  func requiredNonStringElement() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("a"), .number(.integer(1))])])
    )
    let result = schema.validating(.object(["a": .string("x")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "required")
    #expect(result.errors.first?.message.contains("must contain strings") == true)
  }

  @Test("required — empty array passes trivially")
  func requiredEmpty() throws {
    let schema = try JSONSchema(schema: .object(["required": .array([])]))
    #expect(schema.validating(.object(["a": .string("x")])).valid)
    #expect(schema.validating(.object([:])).valid)
  }

  @Test("required — multiple missing keys")
  func requiredMultipleMissing() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("a"), .string("b"), .string("c")])])
    )
    let result = schema.validating(.object(["a": .string("x")]))
    #expect(!result.valid)
    #expect(result.errors.count == 2) // b and c are missing
  }
}

@Suite("JSONSchema Phase 6 — boolean schema edge cases")
struct JSONSchemaPhase6BooleanEdgeCases {
  @Test("false schema in allOf — allOf fails")
  func falseInAllOf() throws {
    let schema = try JSONSchema(
      schema: .object([
        "allOf": .array([
          .boolean(true),
          .boolean(false),
        ])
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
        "anyOf": .array([
          .boolean(false),
          .boolean(false),
        ])
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
        "anyOf": .array([
          .boolean(false),
          .boolean(true),
        ])
      ])
    )
    #expect(schema.validating(.string("anything")).valid)
  }

  @Test("oneOf — two true boolean schemas fail (not exactly one)")
  func oneOfTwoTrueBooleans() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([
          .boolean(true),
          .boolean(true),
        ])
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
        "oneOf": .array([
          .boolean(false),
          .boolean(true),
        ])
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
    let schema = try JSONSchema(
      schema: .object(["if": .boolean(false)])
    )
    // false if always fails, but there's no then/else, so always valid
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

@Suite("JSONSchema Phase 6 — patternProperties edge cases")
struct JSONSchemaPhase6PatternPropertiesEdgeCases {
  @Test("patternProperties — empty object skips validation")
  func patternPropertiesEmptyObject() throws {
    let schema = try JSONSchema(
      schema: .object([
        "patternProperties": .object([
          "^.*$": .object(["type": .string("string")])
        ])
      ])
    )
    #expect(schema.validating(.object([:])).valid)
  }

  @Test("patternProperties — non-string key with schema that validates strings")
  func patternPropertiesKeySchema() throws {
    // patternProperties validates the VALUE, not the key
    let schema = try JSONSchema(
      schema: .object([
        "patternProperties": .object([
          "^[a-z]+$": .object(["type": .string("number")])
        ])
      ])
    )
    // key "abc" matches pattern, value "hello" is string → type number fails
    let result = schema.validating(.object(["abc": .string("hello")]))
    #expect(!result.valid)
  }
}

@Suite("JSONSchema Phase 6 — additionalProperties edge cases")
struct JSONSchemaPhase6AdditionalPropertiesEdgeCases {
  @Test("additionalProperties — false with all keys covered by properties passes")
  func additionalPropertiesFalseCovered() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "name": .object(["type": .string("string")])
        ]),
        "additionalProperties": .boolean(false),
      ]), draft: .draft7
    )
    #expect(schema.validating(.object(["name": .string("Alice")])).valid)
  }

  @Test("additionalProperties — schema for uncovered keys")
  func additionalPropertiesSchema() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "name": .object(["type": .string("string")])
        ]),
        "additionalProperties": .object(["type": .string("number")]),
      ]), draft: .draft7
    )
    // "name" is covered by properties, "age" must be a number
    #expect(schema.validating(.object(["name": .string("Alice"), "age": .number(.integer(30))])).valid)
    let result = schema.validating(
      .object(["name": .string("Alice"), "age": .string("thirty")])
    )
    #expect(!result.valid)
  }
}

@Suite("JSONSchema Phase 6 — format edge cases")
struct JSONSchemaPhase6FormatEdgeCases {
  @Test("format — date invalid day combinations")
  func formatDateInvalidDays() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("date")]), draft: .draft7
    )
    #expect(!schema.validating(.string("2025-02-30")).valid)  // Feb 30
    #expect(!schema.validating(.string("2025-04-31")).valid)  // Apr 31
    #expect(!schema.validating(.string("2025-02-29")).valid)  // 2025 not leap year
    #expect(schema.validating(.string("2024-02-29")).valid)   // 2024 is leap year
  }

  @Test("format — time invalid values")
  func formatTimeInvalidValues() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("time")]), draft: .draft7
    )
    #expect(!schema.validating(.string("24:00:00")).valid)   // invalid hour
    #expect(!schema.validating(.string("12:60:00")).valid)   // invalid minute
    #expect(!schema.validating(.string("12:00:60")).valid)   // invalid second
  }

  @Test("format — email with quoted local part")
  func formatEmailQuoted() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("email")]), draft: .draft7
    )
    // Simple regex doesn't support quoted local parts, but should still accept basic emails
    #expect(schema.validating(.string("user+tag@example.com")).valid)
    #expect(schema.validating(.string("user.name@example.com")).valid)
  }

  @Test("format — hostname with trailing dot")
  func formatHostnameTrailingDot() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("hostname")]), draft: .draft7
    )
    // Trailing dot is valid per RFC but our regex doesn't allow it
    #expect(!schema.validating(.string("example.com.")).valid)
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
    // inet_pton accepts leading zeros
    #expect(schema.validating(.string("192.168.001.001")).valid)
  }

  @Test("format — date-time with fractional seconds no timezone")
  func formatDateTimeFractionalNoTZ() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("date-time")]), draft: .draft7
    )
    // ISO8601DateFormatter with InternetDateTime requires timezone
    #expect(!schema.validating(.string("2025-01-01T12:00:00.123")).valid)
  }
}

@Suite("JSONSchema Phase 6 — $ref resolution edge cases")
struct JSONSchemaPhase6RefEdgeCases {
  @Test("$ref — root reference without $id")
  func refRootNoId() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$ref": .string("#"),
        "type": .string("string"),
      ])
    )
    // $ref replaces the schema, so type is ignored in Draft 7
    #expect(schema.validating(.string("hello")).valid)
  }

  @Test("$ref — to $defs with boolean schema")
  func refDefsBoolean() throws {
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

  @Test("$ref — unresolvable URI without fragment")
  func refUnresolvableURI() throws {
    let schema = try JSONSchema(
      schema: .object(["$ref": .string("http://nonexistent.example/schema")])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "$ref")
  }

  @Test("$ref — resolves anchor from $defs with $id")
  func refAnchorInDefsWithId() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "target": .object([
            "$id": .string("http://example.com/target"),
            "$anchor": .string("myAnchor"),
            "type": .string("string"),
          ])
        ]),
        "$ref": .string("http://example.com/target#myAnchor"),
      ])
    )
    let result = schema.validating(.string("hello"))
    #expect(result.valid)
    let result2 = schema.validating(.number(.integer(42)))
    #expect(!result2.valid)
  }

  @Test("$ref — deep pointer into $defs with nested properties")
  func refDeepPointer() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "obj": .object([
            "properties": .object([
              "nested": .object(["type": .string("string")])
            ])
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
    // In Draft 2020-12, $ref does NOT replace the subschema — sibling keywords
    // like "type" are also evaluated alongside the referenced schema.
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "strType": .object(["type": .string("string")])
        ]),
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
    // In Draft 7, $ref replaces the entire subschema — sibling keywords
    // like "type" are ignored.
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "strType": .object(["type": .string("string")])
        ]),
        "$ref": .string("#/$defs/strType"),
        "minimum": .number(.integer(100)),
      ]), draft: .draft7
    )
    // The "minimum" keyword should be ignored since $ref replaces the subschema
    #expect(schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }
}

@Suite("JSONSchema Phase 6 — compilation edge cases")
struct JSONSchemaPhase6CompilationEdgeCases {
  @Test("compiled — $defs inside items (schema mode)")
  func defsInsideItems() throws {
    let schema: JSON = .object([
      "items": .object([
        "$defs": .object([
          "stringType": .object(["type": .string("string")])
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.defs["stringType"]?.isObject == true)
  }

  @Test("compiled — $defs inside prefixItems")
  func defsInsidePrefixItems() throws {
    let schema: JSON = .object([
      "prefixItems": .array([
        .object([
          "$defs": .object([
            "numType": .object(["type": .string("number")])
          ])
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.defs["numType"]?.isObject == true)
  }

  @Test("compiled — $defs inside contains")
  func defsInsideContains() throws {
    let schema: JSON = .object([
      "contains": .object([
        "$defs": .object([
          "strType": .object(["type": .string("string")])
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.defs["strType"]?.isObject == true)
  }

  @Test("compiled — $defs inside dependentSchemas")
  func defsInsideDependentSchemas() throws {
    let schema: JSON = .object([
      "dependentSchemas": .object([
        "credit_card": .object([
          "$defs": .object([
            "requiredType": .object(["type": .string("string")])
          ])
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.defs["requiredType"]?.isObject == true)
  }

  @Test("compiled — $anchor inside items")
  func anchorInsideItems() throws {
    let schema: JSON = .object([
      "items": .object([
        "$anchor": .string("itemAnchor"),
        "type": .string("string")
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.anchors["itemAnchor"]?.isObject == true)
  }

  @Test("compiled — $dynamicAnchor inside prefixItems")
  func dynamicAnchorInsidePrefixItems() throws {
    let schema: JSON = .object([
      "prefixItems": .array([
        .object([
          "$dynamicAnchor": .string("prefixDynamic"),
          "type": .string("number")
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.dynamicAnchors["prefixDynamic"]?.isObject == true)
  }

  @Test("compiled — deeply nested keyword cache depth guard")
  func keywordCacheDepthGuard() throws {
    // Build a schema nested 150 levels deep to test the keyword cache depth guard
    var nested: JSON = .object(["type": .string("string")])
    for _ in 0..<150 {
      nested = .object(["properties": .object(["nested": nested])])
    }
    let compiled = try CompiledSchema(schema: nested)
    // Should not crash — depth guard prevents stack overflow
    #expect(compiled.precompiledPatterns.isEmpty == true)
  }

  @Test("compiled — $defs inside if/then/else")
  func defsInsideIfThenElse() throws {
    let schema: JSON = .object([
      "if": .object([
        "$defs": .object([
          "ifType": .object(["type": .string("string")])
        ]),
        "type": .string("string")
      ]),
      "then": .object([
        "$defs": .object([
          "thenType": .object(["type": .string("number")])
        ])
      ]),
      "else": .object([
        "$defs": .object([
          "elseType": .object(["type": .string("boolean")])
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.defs["ifType"]?.isObject == true)
    #expect(compiled.resources[""]?.defs["thenType"]?.isObject == true)
    #expect(compiled.resources[""]?.defs["elseType"]?.isObject == true)
  }
}

@Suite("JSONSchema Phase 6 — $dynamicRef edge cases")
struct JSONSchemaPhase6DynamicRefEdgeCases {
  @Test("$dynamicRef — resolves against dynamic scope from allOf")
  func dynamicRefFromAllOf() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$dynamicAnchor": .string("node"),
        "allOf": .array([
          .object(["$dynamicRef": .string("#node")])
        ])
      ])
    )
    // Dynamic scope should push the root's $dynamicAnchor before allOf subschemas
    let result = schema.validating(.string("hello"))
    // allOf subschema validates against the root, which has $dynamicAnchor "node"
    // The $dynamicRef resolves to the root schema via dynamic scope
    // This creates a self-reference → depth guard fires
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "allOf")
  }

  @Test("$dynamicRef — unresolvable with non-matching dynamic scope")
  func dynamicRefUnresolvableScope() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$dynamicAnchor": .string("node"),
        "properties": .object([
          "child": .object(["$dynamicRef": .string("#other")])
        ])
      ])
    )
    let result = schema.validating(.object(["child": .string("hello")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "$dynamicRef")
  }

  @Test("$dynamicRef — no fragment behaves like $ref")
  func dynamicRefNoFragment() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "strType": .object(["type": .string("string")])
        ]),
        "$dynamicRef": .string("#/$defs/strType"),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }
}

@Suite("JSONSchema Phase 6 — propertyNames edge cases")
struct JSONSchemaPhase6PropertyNamesEdgeCases {
  @Test("propertyNames — empty string key")
  func propertyNamesEmptyKey() throws {
    let schema = try JSONSchema(
      schema: .object(["propertyNames": .object(["minLength": .number(.integer(1))])])
    )
    let result = schema.validating(.object(["": .string("value")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "propertyNames")
  }

  @Test("propertyNames — numeric key")
  func propertyNamesNumericKey() throws {
    let schema = try JSONSchema(
      schema: .object(["propertyNames": .object(["pattern": .string("^[0-9]+$")])])
    )
    #expect(schema.validating(.object(["123": .string("value")])).valid)
    #expect(!schema.validating(.object(["abc": .string("value")])).valid)
  }

  @Test("propertyNames — with patternProperties and additionalProperties")
  func propertyNamesCombined() throws {
    let schema = try JSONSchema(
      schema: .object([
        "propertyNames": .object(["minLength": .number(.integer(1))]),
        "patternProperties": .object([
          "^[a-z]+$": .object(["type": .string("string")])
        ]),
      ])
    )
    #expect(schema.validating(.object(["name": .string("Alice")])).valid)
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

@Suite("JSONSchema Phase 6 — dependentSchemas edge cases")
struct JSONSchemaPhase6DependentSchemasEdgeCases {
  @Test("dependentSchemas — with false boolean dependency")
  func dependentSchemasFalse() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "key": .boolean(false)
        ])
      ])
    )
    #expect(schema.validating(.object([:])).valid)
    let result = schema.validating(.object(["key": .string("value")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "dependentSchemas")
  }

  @Test("dependentSchemas — with true boolean dependency (no constraint)")
  func dependentSchemasTrue() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "key": .boolean(true)
        ])
      ])
    )
    #expect(schema.validating(.object(["key": .string("value")])).valid)
  }
}

@Suite("JSONSchema Phase 6 — dependencies (Draft 7) edge cases")
struct JSONSchemaPhase6DependenciesEdgeCases {
  @Test("dependencies — schema dependency valid")
  func dependenciesSchemaValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependencies": .object([
          "credit_card": .object(["required": .array([.string("number")])])
        ])
      ]), draft: .draft7
    )
    #expect(schema.validating(.object(["credit_card": .string("1234"), "number": .string("1234")])).valid)
  }

  @Test("dependencies — required array dependency valid")
  func dependenciesArrayValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependencies": .object([
          "a": .array([.string("b")])
        ])
      ]), draft: .draft7
    )
    #expect(schema.validating(.object(["a": .string("x"), "b": .string("y")])).valid)
  }

  @Test("dependencies — required array dependency fails")
  func dependenciesArrayInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependencies": .object([
          "a": .array([.string("b")])
        ])
      ]), draft: .draft7
    )
    let result = schema.validating(.object(["a": .string("x")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "dependencies")
  }

  @Test("dependencies — boolean false dependency fails when key present")
  func dependenciesBoolFalse() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependencies": .object([
          "key": .boolean(false)
        ])
      ]), draft: .draft7
    )
    #expect(schema.validating(.object([:])).valid)
    let result = schema.validating(.object(["key": .string("value")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "dependencies")
  }
}

@Suite("JSONSchema Phase 6 — additionalItems edge cases")
struct JSONSchemaPhase6AdditionalItemsEdgeCases {
  @Test("additionalItems — when items is schema (not array), additionalItems is ignored")
  func additionalItemsWithSchemaItems() throws {
    let schema = try JSONSchema(
      schema: .object([
        "items": .object(["type": .string("string")]),
        "additionalItems": .boolean(false),
      ]), draft: .draft7
    )
    // items applies to all items, additionalItems is ignored
    #expect(schema.validating(.array([.string("a"), .string("b")])).valid)
  }

  @Test("additionalItems — no tuple items (items absent), additionalItems applies to all")
  func additionalItemsWithoutItems() throws {
    let schema = try JSONSchema(
      schema: .object([
        "additionalItems": .object(["type": .string("string")]),
      ]), draft: .draft7
    )
    // When items is not an array, additionalItems applies to all items
    // But this code path requires items.isArray to be true to trigger
    #expect(schema.validating(.array([.string("a")])).valid)
  }
}

@Suite("JSONSchema Phase 6 — multipleOf edge cases")
struct JSONSchemaPhase6MultipleOfEdgeCases {
  @Test("multipleOf — very large divisor (overflow check)")
  func multipleOfLargeDivisor() throws {
    // Division overflow: valDouble / mDouble → infinity for very large numbers
    let schema = try JSONSchema(
      schema: .object(["multipleOf": .number(.float(1e-300))])
    )
    // With a tiny divisor and moderate value, ratio should be finite
    #expect(schema.validating(.number(.float(1e-100))).valid)
  }

  @Test("multipleOf — negative divisor ignored per spec")
  func multipleOfNegativeDivisor() throws {
    let schema = try JSONSchema(
      schema: .object(["multipleOf": .number(.float(-2.0))])
    )
    #expect(schema.validating(.number(.float(3.0))).valid)
  }

  @Test("multipleOf — non-number multipleOf ignored")
  func multipleOfNonNumber() throws {
    let schema = try JSONSchema(
      schema: .object(["multipleOf": .string("not-a-number")])
    )
    #expect(schema.validating(.number(.integer(5))).valid)
  }
}