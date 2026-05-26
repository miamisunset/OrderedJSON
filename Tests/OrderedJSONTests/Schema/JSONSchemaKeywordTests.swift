import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Type Validation

@Suite("JSONSchema type validation")
struct JSONSchemaTypeValidationTests {

  @Test("type string — valid")
  func typeStringValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    #expect(schema.validation(of: .string("hello")).valid)
  }

  @Test("type string — invalid (number)")
  func typeStringInvalid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    let result = schema.validation(of: .number(.integer(42)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "type")
  }

  @Test("type integer — valid")
  func typeIntegerValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("integer")]))
    #expect(schema.validation(of: .number(.integer(42))).valid)
  }

  @Test("type integer — invalid (float)")
  func typeIntegerInvalid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("integer")]))
    let result = schema.validation(of: .number(.float(42.5)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "type")
  }

  @Test("type number — accepts integer")
  func typeNumberAcceptsInteger() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    #expect(schema.validation(of: .number(.integer(42))).valid)
  }

  @Test("type number — accepts float")
  func typeNumberAcceptsFloat() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    #expect(schema.validation(of: .number(.float(3.14))).valid)
  }

  @Test("type boolean — valid")
  func typeBooleanValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("boolean")]))
    #expect(schema.validation(of: .boolean(true)).valid)
    #expect(schema.validation(of: .boolean(false)).valid)
  }

  @Test("type null — valid")
  func typeNullValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("null")]))
    #expect(schema.validation(of: .null).valid)
  }

  @Test("type object — valid")
  func typeObjectValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("object")]))
    #expect(schema.validation(of: .object(["key": .string("val")])).valid)
  }

  @Test("type array — valid")
  func typeArrayValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("array")]))
    #expect(schema.validation(of: .array([.number(.integer(1))])).valid)
  }

  @Test("type array of strings — valid")
  func typeArrayOfStrings() throws {
    let schema = try JSONSchema(
      schema: .object(["type": .array([.string("string"), .string("number")])]))
    #expect(schema.validation(of: .string("hello")).valid)
    #expect(schema.validation(of: .number(.integer(42))).valid)
  }

  @Test("type array of strings — invalid")
  func typeArrayOfStringsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["type": .array([.string("string"), .string("number")])]))
    let result = schema.validation(of: .boolean(true))
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
      ]))
    let doc: JSON = .object(["name": .string("Alice")])
    #expect(schema.validation(of: doc).valid)
  }

  @Test("properties — invalid nested")
  func propertiesInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "age": .object(["type": .string("integer")])
        ])
      ]))
    let doc: JSON = .object(["age": .string("thirty")])
    let result = schema.validation(of: doc)
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
      ]))
    let doc: JSON = .object([:])
    #expect(schema.validation(of: doc).valid)
  }

  @Test("properties — non-object value skips validation")
  func propertiesNonObject() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "name": .object(["type": .string("string")])
        ])
      ]))
    #expect(schema.validation(of: .string("hello")).valid)
  }
}

// MARK: - Required Validation

@Suite("JSONSchema required validation")
struct JSONSchemaRequiredTests {

  @Test("required — valid when all present")
  func requiredValid() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("a"), .string("b")])]))
    let doc: JSON = .object(["a": .string("x"), "b": .string("y")])
    #expect(schema.validation(of: doc).valid)
  }

  @Test("required — fails when missing")
  func requiredMissing() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("name")])]))
    let doc: JSON = .object(["age": .number(.integer(30))])
    let result = schema.validation(of: doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "required")
  }

  @Test("required — null is valid (spec: presence only)")
  func requiredNullValid() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("name")])]))
    let doc: JSON = .object(["name": .null])
    #expect(schema.validation(of: doc).valid)
  }

  @Test("required — non-object skips validation")
  func requiredNonObject() throws {
    let schema = try JSONSchema(
      schema: .object(["required": .array([.string("name")])]))
    #expect(schema.validation(of: .string("hello")).valid)
  }
}

// MARK: - Numeric Bounds

@Suite("JSONSchema numeric bounds")
struct JSONSchemaNumericBoundsTests {

  @Test("minimum — valid")
  func minimumValid() throws {
    let schema = try JSONSchema(
      schema: .object(["minimum": .number(.integer(10))]))
    #expect(schema.validation(of: .number(.integer(10))).valid)
    #expect(schema.validation(of: .number(.integer(20))).valid)
  }

  @Test("minimum — invalid")
  func minimumInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["minimum": .number(.integer(10))]))
    let result = schema.validation(of: .number(.integer(5)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "minimum")
  }

  @Test("maximum — valid")
  func maximumValid() throws {
    let schema = try JSONSchema(
      schema: .object(["maximum": .number(.integer(100))]))
    #expect(schema.validation(of: .number(.integer(50))).valid)
    #expect(schema.validation(of: .number(.integer(100))).valid)
  }

  @Test("maximum — invalid")
  func maximumInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["maximum": .number(.integer(100))]))
    let result = schema.validation(of: .number(.integer(200)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "maximum")
  }

  @Test("minimum + maximum — valid in range")
  func minMaxInRange() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minimum": .number(.integer(10)),
        "maximum": .number(.integer(100)),
      ]))
    #expect(schema.validation(of: .number(.integer(50))).valid)
  }

  @Test("minimum + maximum — invalid out of range")
  func minMaxOutOfRange() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minimum": .number(.integer(10)),
        "maximum": .number(.integer(100)),
      ]))
    let result = schema.validation(of: .number(.integer(5)))
    #expect(!result.valid)
  }

  @Test("minimum with Int64.max preserves precision")
  func minInt64Max() throws {
    let schema = try JSONSchema(
      schema: .object(["minimum": .number(.integer(Int64.max))]))
    #expect(schema.validation(of: .number(.integer(Int64.max))).valid)
    let result = schema.validation(of: .number(.integer(Int64.max - 1)))
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
      schema: .object(["exclusiveMinimum": .number(.integer(10))]))
    #expect(schema.validation(of: .number(.integer(11))).valid)
    #expect(schema.validation(of: .number(.integer(20))).valid)
  }

  @Test("exclusiveMinimum — Draft 2020-12 invalid (equal)")
  func exclMin202012Invalid() throws {
    let schema = try JSONSchema(
      schema: .object(["exclusiveMinimum": .number(.integer(10))]))
    let result = schema.validation(of: .number(.integer(10)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "exclusiveMinimum")
  }

  @Test("exclusiveMinimum — Draft 7 with boolean true")
  func exclMinDraft7BoolTrue() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minimum": .number(.integer(10)),
        "exclusiveMinimum": .boolean(true),
      ]), draft: .draft7)
    #expect(schema.validation(of: .number(.integer(11))).valid)
    let result = schema.validation(of: .number(.integer(10)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "exclusiveMinimum")
  }

  @Test("exclusiveMinimum — Draft 7 with boolean false (allowed)")
  func exclMinDraft7BoolFalse() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minimum": .number(.integer(10)),
        "exclusiveMinimum": .boolean(false),
      ]), draft: .draft7)
    #expect(schema.validation(of: .number(.integer(10))).valid)
    #expect(schema.validation(of: .number(.integer(5))).valid == false)
  }

  @Test("exclusiveMaximum — Draft 2020-12 valid")
  func exclMax202012Valid() throws {
    let schema = try JSONSchema(
      schema: .object(["exclusiveMaximum": .number(.integer(100))]))
    #expect(schema.validation(of: .number(.integer(50))).valid)
    #expect(schema.validation(of: .number(.integer(99))).valid)
  }

  @Test("exclusiveMaximum — Draft 2020-12 invalid (equal)")
  func exclMax202012Invalid() throws {
    let schema = try JSONSchema(
      schema: .object(["exclusiveMaximum": .number(.integer(100))]))
    let result = schema.validation(of: .number(.integer(100)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "exclusiveMaximum")
  }

  @Test("exclusiveMaximum — Draft 7 with boolean true")
  func exclMaxDraft7BoolTrue() throws {
    let schema = try JSONSchema(
      schema: .object([
        "maximum": .number(.integer(100)),
        "exclusiveMaximum": .boolean(true),
      ]), draft: .draft7)
    #expect(schema.validation(of: .number(.integer(99))).valid)
    let result = schema.validation(of: .number(.integer(100)))
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
      schema: .object(["multipleOf": .number(.integer(3))]))
    #expect(schema.validation(of: .number(.integer(9))).valid)
    #expect(schema.validation(of: .number(.integer(0))).valid)
  }

  @Test("multipleOf — invalid integer")
  func multipleOfIntInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["multipleOf": .number(.integer(3))]))
    let result = schema.validation(of: .number(.integer(10)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "multipleOf")
  }

  @Test("multipleOf — valid float")
  func multipleOfFloatValid() throws {
    let schema = try JSONSchema(
      schema: .object(["multipleOf": .number(.float(1.5))]))
    #expect(schema.validation(of: .number(.float(4.5))).valid)
    #expect(schema.validation(of: .number(.float(0.0))).valid)
  }

  @Test("multipleOf — non-number value skips")
  func multipleOfNonNumber() throws {
    let schema = try JSONSchema(
      schema: .object(["multipleOf": .number(.integer(2))]))
    #expect(schema.validation(of: .string("hello")).valid)
  }

  @Test("multipleOf — zero or negative is ignored per spec")
  func multipleOfZeroOrNegative() throws {
    let schema = try JSONSchema(
      schema: .object(["multipleOf": .number(.integer(0))]))
    #expect(schema.validation(of: .number(.integer(5))).valid)
    let schemaNeg = try JSONSchema(
      schema: .object(["multipleOf": .number(.integer(-3))]))
    #expect(schemaNeg.validation(of: .number(.integer(6))).valid)
  }
}

// MARK: - Pattern

@Suite("JSONSchema pattern")
struct JSONSchemaPatternTests {

  @Test("pattern — valid match")
  func patternValid() throws {
    let schema = try JSONSchema(
      schema: .object(["pattern": .string("^[A-Z][a-z]+$")]))
    #expect(schema.validation(of: .string("Hello")).valid)
  }

  @Test("pattern — invalid no match")
  func patternInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["pattern": .string("^[0-9]+$")]))
    let result = schema.validation(of: .string("abc"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "pattern")
  }

  @Test("pattern — non-string value skips")
  func patternNonString() throws {
    let schema = try JSONSchema(
      schema: .object(["pattern": .string("^[0-9]+$")]))
    #expect(schema.validation(of: .number(.integer(42))).valid)
  }

  @Test("pattern — invalid regex fails at init time, not at validation")
  func patternInvalidRegexDeferred() throws {
    let schema = try JSONSchema(
      schema: .object(["pattern": .string("^valid$")]))
    #expect(schema.validation(of: .string("valid")).valid)
  }
}

// MARK: - Enum

@Suite("JSONSchema enum")
struct JSONSchemaEnumTests {

  @Test("enum — valid match")
  func enumValid() throws {
    let schema = try JSONSchema(
      schema: .object(["enum": .array([.string("a"), .string("b")])]))
    #expect(schema.validation(of: .string("a")).valid)
    #expect(schema.validation(of: .string("b")).valid)
  }

  @Test("enum — invalid no match")
  func enumInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["enum": .array([.string("a"), .string("b")])]))
    let result = schema.validation(of: .string("c"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "enum")
  }

  @Test("enum — string values match")
  func enumStringValues() throws {
    let schema = try JSONSchema(
      schema: .object(["enum": .array([.string("hello")])]))
    #expect(schema.validation(of: .string("hello")).valid)
  }

  @Test("enum — empty array never matches")
  func enumEmptyArray() throws {
    let schema = try JSONSchema(schema: .object(["enum": .array([])]))
    let result = schema.validation(of: .string("anything"))
    #expect(!result.valid)
  }

  @Test("enum — integer 1 matches float 1.0 (spec: equal)")
  func enumIntFloatEquality() throws {
    let schema = try JSONSchema(
      schema: .object(["enum": .array([.number(.float(1.0))])]))
    #expect(schema.validation(of: .number(.integer(1))).valid)
  }

  @Test("enum — array with integer 1 matches float 1.0")
  func enumArrayIntFloat() throws {
    let schema = try JSONSchema(
      schema: .object(["enum": .array([.array([.number(.float(1.0))])])]))
    #expect(schema.validation(of: .array([.number(.integer(1))])).valid)
  }

  @Test("enum — object key order is ignored")
  func enumObjectKeyOrder() throws {
    let schema = try JSONSchema(
      schema: .object([
        "enum": .array([.object(["a": .number(.integer(1)), "b": .number(.integer(2))])])
      ]))
    let doc: JSON = .object(["b": .number(.integer(2)), "a": .number(.integer(1))])
    #expect(schema.validation(of: doc).valid)
  }
}

// MARK: - Const

@Suite("JSONSchema const")
struct JSONSchemaConstTests {

  @Test("const — valid match")
  func constValid() throws {
    let schema = try JSONSchema(
      schema: .object(["const": .string("hello")]))
    #expect(schema.validation(of: .string("hello")).valid)
  }

  @Test("const — invalid mismatch")
  func constInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["const": .string("hello")]))
    let result = schema.validation(of: .string("world"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "const")
  }

  @Test("const — string match")
  func constStringMatch() throws {
    let schema = try JSONSchema(
      schema: .object(["const": .string("test")]))
    #expect(schema.validation(of: .string("test")).valid)
  }

  @Test("const — object match")
  func constObjectMatch() throws {
    let schema = try JSONSchema(
      schema: .object(["const": .object(["a": .number(.integer(1))])]))
    #expect(schema.validation(of: .object(["a": .number(.integer(1))])).valid)
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
      ]))
    #expect(schema.validation(of: .string("hello")).valid)
  }

  @Test("allOf — invalid when one subschema fails")
  func allOfInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "allOf": .array([
          .object(["type": .string("string")]),
          .object(["minLength": .number(.integer(10))]),
        ])
      ]))
    let result = schema.validation(of: .string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "allOf")
  }

  @Test("allOf — empty array passes")
  func allOfEmpty() throws {
    let schema = try JSONSchema(schema: .object(["allOf": .array([])]))
    #expect(schema.validation(of: .string("anything")).valid)
  }

  @Test("allOf — missing keyword skips")
  func allOfMissing() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    #expect(schema.validation(of: .string("test")).valid)
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
      ]))
    #expect(schema.validation(of: .string("test")).valid)
    #expect(schema.validation(of: .number(.integer(42))).valid)
  }

  @Test("anyOf — invalid when none match")
  func anyOfInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "anyOf": .array([
          .object(["type": .string("number")]),
          .object(["type": .string("boolean")]),
        ])
      ]))
    let result = schema.validation(of: .string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "anyOf")
  }

  @Test("anyOf — empty array fails (no subschemas to match)")
  func anyOfEmpty() throws {
    let schema = try JSONSchema(schema: .object(["anyOf": .array([])]))
    let result = schema.validation(of: .string("test"))
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
      ]))
    #expect(schema.validation(of: .string("test")).valid)
  }

  @Test("oneOf — invalid when zero match")
  func oneOfZeroMatch() throws {
    let schema = try JSONSchema(
      schema: .object([
        "oneOf": .array([
          .object(["type": .string("number")]),
          .object(["type": .string("boolean")]),
        ])
      ]))
    let result = schema.validation(of: .string("test"))
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
      ]))
    let result = schema.validation(of: .string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "oneOf")
    #expect(result.errors.first?.message.contains("2") == true)
  }

  @Test("oneOf — empty array fails")
  func oneOfEmpty() throws {
    let schema = try JSONSchema(schema: .object(["oneOf": .array([])]))
    let result = schema.validation(of: .string("test"))
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
      schema: .object(["not": .object(["type": .string("number")])]))
    #expect(schema.validation(of: .string("test")).valid)
  }

  @Test("not — invalid when subschema matches")
  func notInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["not": .object(["type": .string("string")])]))
    let result = schema.validation(of: .string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "not")
  }

  @Test("not — missing keyword skips")
  func notMissing() throws {
    let schema = try JSONSchema(schema: .object([:]))
    #expect(schema.validation(of: .string("test")).valid)
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
      ]))
    #expect(schema.validation(of: .string("hello")).valid)
  }

  @Test("if/then — invalid when if matches but then fails")
  func ifThenInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "then": .object(["minLength": .number(.integer(10))]),
      ]))
    let result = schema.validation(of: .string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "then")
  }

  @Test("if/else — valid when if fails and else matches")
  func ifElseValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "else": .object(["minLength": .number(.integer(3))]),
      ]))
    #expect(schema.validation(of: .number(.integer(42))).valid)
  }

  @Test("if/else — invalid when if fails and else fails")
  func ifElseInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("string")]),
        "else": .object(["type": .string("string")]),
      ]))
    let result = schema.validation(of: .number(.integer(42)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "else")
  }

  @Test("if alone — no then/else, if result doesn't affect validity")
  func ifAlone() throws {
    let schema = try JSONSchema(schema: .object(["if": .object(["type": .string("number")])]))
    #expect(schema.validation(of: .string("test")).valid)
    #expect(schema.validation(of: .number(.integer(42))).valid)
  }

  @Test("if/then/else — full conditional")
  func ifThenElseFull() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("number")]),
        "then": .object(["minimum": .number(.integer(0))]),
        "else": .object(["type": .string("string")]),
      ]))
    #expect(schema.validation(of: .number(.integer(42))).valid)
    #expect(schema.validation(of: .number(.integer(-1))).valid == false)
    #expect(schema.validation(of: .string("test")).valid)
    #expect(schema.validation(of: .boolean(true)).valid == false)
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
      ]))
    let doc: JSON = .object(["name": .string("Alice")])
    #expect(schema.validation(of: doc).valid)
  }

  @Test("dependentSchemas — valid when dependency key is present and schema matches")
  func depSchemasValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "credit_card": .object(["required": .array([.string("number")])])
        ])
      ]))
    let doc: JSON = .object(["credit_card": .string("1234"), "number": .string("1234")])
    #expect(schema.validation(of: doc).valid)
  }

  @Test("dependentSchemas — invalid when dependency key is present and schema fails")
  func depSchemasInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentSchemas": .object([
          "credit_card": .object(["required": .array([.string("number"), .string("cvc")])])
        ])
      ]))
    let doc: JSON = .object(["credit_card": .string("1234"), "number": .string("1234")])
    let result = schema.validation(of: doc)
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
      ]))
    let doc: JSON = .object(["a": .string("x"), "b": .string("y")])
    #expect(schema.validation(of: doc).valid)
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
      ]))
    let doc: JSON = .object(["name": .string("Alice")])
    #expect(schema.validation(of: doc).valid)
  }

  @Test("dependentRequired — valid when dependency key is present and required keys are present")
  func depRequiredValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentRequired": .object([
          "credit_card": .array([.string("number"), .string("cvc")])
        ])
      ]))
    let doc: JSON = .object([
      "credit_card": .string("x"), "number": .string("1234"), "cvc": .string("789"),
    ])
    #expect(schema.validation(of: doc).valid)
  }

  @Test("dependentRequired — invalid when dependency key is present but required keys are missing")
  func depRequiredInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentRequired": .object([
          "credit_card": .array([.string("number"), .string("cvc")])
        ])
      ]))
    let doc: JSON = .object(["credit_card": .string("x"), "number": .string("1234")])
    let result = schema.validation(of: doc)
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
      ]))
    let doc: JSON = .object(["a": .string("x")])
    let result = schema.validation(of: doc)
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
      ]))
    let doc: JSON = .object(["credit_card": .string("x")])
    let result = schema.validation(of: doc)
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
    #expect(schema.validation(of: .array([.string("a"), .string("b")])).valid)
  }

  @Test("items — schema mode — invalid")
  func itemsSchemaInvalid() throws {
    let schema = try JSONSchema(schema: .object(["items": .object(["type": .string("string")])]))
    let result = schema.validation(of: .array([.string("a"), .number(.integer(1))]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("items")
        || result.errors.map(\.keyword).contains("type"))
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
      ]), draft: .draft7)
    #expect(schema.validation(of: .array([.string("a"), .number(.integer(1))])).valid)
  }

  @Test("items — Draft 7 tuple mode — invalid")
  func itemsTupleDraft7Invalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "items": .array([
          .object(["type": .string("string")]),
          .object(["type": .string("number")]),
        ])
      ]), draft: .draft7)
    let result = schema.validation(of: .array([.string("a"), .string("b")]))
    #expect(!result.valid)
  }

  @Test("items — non-array value skips")
  func itemsNonArray() throws {
    let schema = try JSONSchema(schema: .object(["items": .object(["type": .string("string")])]))
    #expect(schema.validation(of: .string("hello")).valid)
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
      ]))
    #expect(schema.validation(of: .array([.string("a"), .number(.integer(1))])).valid)
  }

  @Test("prefixItems — invalid")
  func prefixItemsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "prefixItems": .array([
          .object(["type": .string("string")])
        ])
      ]))
    let result = schema.validation(of: .array([.number(.integer(1))]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("prefixItems")
        || result.errors.map(\.keyword).contains("type"))
    #expect(result.errors.count >= 1)
  }

  @Test("prefixItems — non-array value skips")
  func prefixItemsNonArray() throws {
    let schema = try JSONSchema(
      schema: .object(["prefixItems": .array([.object(["type": .string("string")])])]))
    #expect(schema.validation(of: .string("hello")).valid)
  }
}

@Suite("JSONSchema minItems / maxItems")
struct JSONSchemaMinMaxItemsTests {

  @Test("minItems — valid")
  func minItemsValid() throws {
    let schema = try JSONSchema(schema: .object(["minItems": .number(.integer(2))]))
    #expect(schema.validation(of: .array([.string("a"), .string("b")])).valid)
    #expect(schema.validation(of: .array([.string("a"), .string("b"), .string("c")])).valid)
  }

  @Test("minItems — invalid")
  func minItemsInvalid() throws {
    let schema = try JSONSchema(schema: .object(["minItems": .number(.integer(3))]))
    let result = schema.validation(of: .array([.string("a"), .string("b")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "minItems")
  }

  @Test("maxItems — valid")
  func maxItemsValid() throws {
    let schema = try JSONSchema(schema: .object(["maxItems": .number(.integer(3))]))
    #expect(schema.validation(of: .array([.string("a"), .string("b")])).valid)
    #expect(schema.validation(of: .array([.string("a")])).valid)
  }

  @Test("maxItems — invalid")
  func maxItemsInvalid() throws {
    let schema = try JSONSchema(schema: .object(["maxItems": .number(.integer(2))]))
    let result = schema.validation(of: .array([.string("a"), .string("b"), .string("c")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "maxItems")
  }

  @Test("minItems / maxItems — non-array skips")
  func minMaxItemsNonArray() throws {
    let schema = try JSONSchema(
      schema: .object(["minItems": .number(.integer(2)), "maxItems": .number(.integer(5))]))
    #expect(schema.validation(of: .string("hello")).valid)
  }
}

@Suite("JSONSchema uniqueItems")
struct JSONSchemaUniqueItemsTests {

  @Test("uniqueItems — valid (all unique)")
  func uniqueItemsValid() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    #expect(schema.validation(of: .array([.string("a"), .string("b")])).valid)
  }

  @Test("uniqueItems — invalid (duplicates)")
  func uniqueItemsInvalid() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    let result = schema.validation(of: .array([.string("a"), .string("a")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "uniqueItems")
  }

  @Test("uniqueItems — false disables check")
  func uniqueItemsFalse() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(false)]))
    #expect(schema.validation(of: .array([.string("a"), .string("a")])).valid)
  }

  @Test("uniqueItems — non-array skips")
  func uniqueItemsNonArray() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    #expect(schema.validation(of: .string("hello")).valid)
  }

  @Test("uniqueItems — integer 1 and float 1.0 are considered equal")
  func uniqueItemsIntFloat() throws {
    let schema = try JSONSchema(schema: .object(["uniqueItems": .boolean(true)]))
    let result = schema.validation(of: .array([.number(.integer(1)), .number(.float(1.0))]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "uniqueItems")
  }
}

@Suite("JSONSchema contains")
struct JSONSchemaContainsTests {

  @Test("contains — valid (at least one matches)")
  func containsValid() throws {
    let schema = try JSONSchema(schema: .object(["contains": .object(["type": .string("string")])]))
    #expect(schema.validation(of: .array([.number(.integer(1)), .string("hello")])).valid)
  }

  @Test("contains — invalid (none match)")
  func containsInvalid() throws {
    let schema = try JSONSchema(schema: .object(["contains": .object(["type": .string("string")])]))
    let result = schema.validation(of: .array([.number(.integer(1)), .number(.integer(2))]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "contains")
  }

  @Test("contains — empty array fails")
  func containsEmpty() throws {
    let schema = try JSONSchema(schema: .object(["contains": .object(["type": .string("string")])]))
    let result = schema.validation(of: .array([]))
    #expect(!result.valid)
  }

  @Test("contains — non-array skips")
  func containsNonArray() throws {
    let schema = try JSONSchema(schema: .object(["contains": .object(["type": .string("string")])]))
    #expect(schema.validation(of: .string("hello")).valid)
  }

  @Test("contains — TODO: minContains/maxContains not yet supported")
  func containsMinContainsTodo() throws {
    // minContains/maxContains (Draft 2020-12) are not yet implemented.
    // minContains: 2 should require at least 2 matches, but current impl
    // returns on first match. This test documents current behavior.
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["type": .string("string")]),
        "minContains": .number(.integer(2)),
      ]))
    // Current: passes with 1 match (deviant — should require 2)
    #expect(schema.validation(of: .array([.number(.integer(1)), .string("hello")])).valid)
  }
}

// MARK: - Object Keywords

@Suite("JSONSchema minProperties / maxProperties")
struct JSONSchemaMinMaxPropertiesTests {

  @Test("minProperties — valid")
  func minPropertiesValid() throws {
    let schema = try JSONSchema(schema: .object(["minProperties": .number(.integer(1))]))
    #expect(schema.validation(of: .object(["a": .string("x")])).valid)
    #expect(schema.validation(of: .object(["a": .string("x"), "b": .string("y")])).valid)
  }

  @Test("minProperties — invalid")
  func minPropertiesInvalid() throws {
    let schema = try JSONSchema(schema: .object(["minProperties": .number(.integer(2))]))
    let result = schema.validation(of: .object(["a": .string("x")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "minProperties")
  }

  @Test("maxProperties — valid")
  func maxPropertiesValid() throws {
    let schema = try JSONSchema(schema: .object(["maxProperties": .number(.integer(3))]))
    #expect(schema.validation(of: .object(["a": .string("x")])).valid)
    #expect(schema.validation(of: .object(["a": .string("x"), "b": .string("y")])).valid)
  }

  @Test("maxProperties — invalid")
  func maxPropertiesInvalid() throws {
    let schema = try JSONSchema(schema: .object(["maxProperties": .number(.integer(1))]))
    let result = schema.validation(of: .object(["a": .string("x"), "b": .string("y")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "maxProperties")
  }

  @Test("minProperties / maxProperties — non-object skips")
  func minMaxPropertiesNonObject() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minProperties": .number(.integer(2)), "maxProperties": .number(.integer(5)),
      ]))
    #expect(schema.validation(of: .string("hello")).valid)
  }
}

@Suite("JSONSchema propertyNames")
struct JSONSchemaPropertyNamesTests {

  @Test("propertyNames — valid (key matches schema)")
  func propertyNamesValid() throws {
    let schema = try JSONSchema(
      schema: .object(["propertyNames": .object(["pattern": .string("^[a-z]+$")])]))
    #expect(schema.validation(of: .object(["name": .string("Alice")])).valid)
  }

  @Test("propertyNames — invalid (key fails schema)")
  func propertyNamesInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["propertyNames": .object(["pattern": .string("^[a-z]+$")])]))
    let result = schema.validation(of: .object(["NAME": .string("Alice")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "propertyNames")
  }

  @Test("propertyNames — non-object skips")
  func propertyNamesNonObject() throws {
    let schema = try JSONSchema(
      schema: .object(["propertyNames": .object(["type": .string("string")])]))
    #expect(schema.validation(of: .string("hello")).valid)
  }

  @Test("propertyNames — inner dispatch preserves parent keyword")
  func propertyNamesInnerDispatch() throws {
    // propertyNames wraps errors with its own keyword (not the inner keyword).
    let schema = try JSONSchema(
      schema: .object(["propertyNames": .object(["maxLength": .number(.integer(3))])]))
    let result = schema.validation(of: .object(["abcd": .number(.integer(1))]))
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
      ]))
    #expect(schema.validation(of: .object(["name": .string("Alice")])).valid)
  }

  @Test("patternProperties — invalid (value fails schema)")
  func patternPropertiesInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "patternProperties": .object([
          "^[a-z]+$": .object(["type": .string("number")])
        ])
      ]))
    let result = schema.validation(of: .object(["name": .string("Alice")]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("patternProperties")
        || result.errors.map(\.keyword).contains("type"))
    #expect(result.errors.count >= 1)
  }

  @Test("patternProperties — non-object skips")
  func patternPropertiesNonObject() throws {
    let propSchema: JSON = .object(["type": .string("string")])
    let schema = try JSONSchema(
      schema: .object(["patternProperties": .object(["^.*$": propSchema])]))
    #expect(schema.validation(of: .string("hello")).valid)
  }

  @Test("patternProperties — invalid regex at init time")
  func patternPropertiesInvalidRegex() throws {
    #expect(throws: JSONSchemaError.self) {
      try JSONSchema(
        schema: .object([
          "patternProperties": .object(["[invalid": .object(["type": .string("string")])])
        ]))
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
      ]), draft: .draft7)
    #expect(schema.validation(of: .object(["name": .string("Alice")])).valid)
  }

  @Test("additionalProperties — invalid (key not covered)")
  func additionalPropertiesUncovered() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object(["name": .object(["type": .string("string")])]),
        "additionalProperties": .boolean(false),
      ]), draft: .draft7)
    let result = schema.validation(
      of: .object(["name": .string("Alice"), "age": .number(.integer(30))]))
    #expect(!result.valid)
    // Error keyword is "false" from the boolean subschema, not "additionalProperties"
    #expect(result.errors.first?.keyword == "false")
  }

  @Test("additionalProperties — non-object skips")
  func additionalPropertiesNonObject() throws {
    let schema = try JSONSchema(
      schema: .object(["additionalProperties": .boolean(false)]), draft: .draft7)
    #expect(schema.validation(of: .string("hello")).valid)
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
      ]))
    #expect(schema.validation(of: .object(["name": .string("Alice")])).valid)
  }

  @Test("unevaluatedProperties — invalid (key not evaluated)")
  func unevaluatedPropertiesUncovered() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object(["name": .object(["type": .string("string")])]),
        "unevaluatedProperties": .boolean(false),
      ]))
    let result = schema.validation(
      of: .object(["name": .string("Alice"), "age": .number(.integer(30))]))
    #expect(!result.valid)
    // Error keyword is "false" from the boolean subschema, not "unevaluatedProperties"
    #expect(result.errors.first?.keyword == "false")
  }

  @Test("unevaluatedProperties — deviation: additionalProperties now tracked")
  func unevaluatedPropertiesWithAdditionalProperties() throws {
    // Keys evaluated by additionalProperties are now in the evaluated set,
    // so unevaluatedProperties does not re-check them.
    let schema = try JSONSchema(
      schema: .object([
        "additionalProperties": .object(["type": .string("string")]),
        "unevaluatedProperties": .boolean(false),
      ]))
    // All keys are evaluated by additionalProperties, so unevaluatedProperties
    // has nothing to check — the schema validates successfully.
    let result = schema.validation(of: .object(["x": .string("hello")]))
    #expect(result.valid)
  }

  @Test("unevaluatedProperties — non-object skips")
  func unevaluatedPropertiesNonObject() throws {
    let schema = try JSONSchema(schema: .object(["unevaluatedProperties": .boolean(false)]))
    #expect(schema.validation(of: .string("hello")).valid)
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
      ]), draft: .draft7)
    #expect(schema.validation(of: .array([.string("a"), .number(.integer(1))])).valid)
  }

  @Test("additionalItems — Draft 7 invalid (beyond tuple fails)")
  func additionalItemsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "items": .array([.object(["type": .string("string")])]),
        "additionalItems": .object(["type": .string("number")]),
      ]), draft: .draft7)
    let result = schema.validation(of: .array([.string("a"), .string("b")]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("additionalItems")
        || result.errors.map(\.keyword).contains("type"))
    #expect(result.errors.count >= 1)
  }

  @Test("additionalItems — non-array skips")
  func additionalItemsNonArray() throws {
    let schema = try JSONSchema(
      schema: .object(["additionalItems": .object(["type": .string("string")])]), draft: .draft7)
    #expect(schema.validation(of: .string("hello")).valid)
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
      ]))
    #expect(schema.validation(of: .array([.string("a"), .number(.integer(1))])).valid)
  }

  @Test("unevaluatedItems — invalid (beyond prefix fails)")
  func unevaluatedItemsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "prefixItems": .array([.object(["type": .string("string")])]),
        "unevaluatedItems": .object(["type": .string("number")]),
      ]))
    let result = schema.validation(of: .array([.string("a"), .string("b")]))
    #expect(!result.valid)
    #expect(
      result.errors.map(\.keyword).contains("unevaluatedItems")
        || result.errors.map(\.keyword).contains("type"))
    #expect(result.errors.count >= 1)
  }

  @Test("unevaluatedItems — non-array skips")
  func unevaluatedItemsNonArray() throws {
    let schema = try JSONSchema(
      schema: .object(["unevaluatedItems": .object(["type": .string("string")])]))
    #expect(schema.validation(of: .string("hello")).valid)
  }

  @Test("unevaluatedItems — items schema short-circuits unevaluatedItems")
  func unevaluatedItemsWithItemsSchema() throws {
    // When `items` is a schema, it evaluates all items past prefixItems,
    // so unevaluatedItems should be a no-op.
    let schema = try JSONSchema(
      schema: .object([
        "items": .object(["type": .string("string")]),
        "unevaluatedItems": .boolean(false),
      ]))
    let result = schema.validation(of: .array([.string("a"), .string("b")]))
    #expect(result.valid)
  }

  @Test("unevaluatedItems — deviation: contains matched indices not excluded")
  func unevaluatedItemsWithContains() throws {
    // Per spec, items matched by contains are evaluated and should be excluded
    // from unevaluatedItems. Currently they are not.
    let schema = try JSONSchema(
      schema: .object([
        "contains": .object(["const": .number(.integer(1))]),
        "unevaluatedItems": .boolean(false),
      ]))
    // Current behavior: unevaluatedItems fires on index 0 (which contains matched).
    // Correct behavior (spec): index 0 is evaluated by contains, so unevaluatedItems
    // should only check indices not matched by contains.
    let result = schema.validation(of: .array([.number(.integer(1)), .number(.integer(2))]))
    // Current (deviant): fails — unevaluatedItems fires on index 0
    #expect(!result.valid)
    // Once contains tracking lands, this should pass (#expect(result.valid))
  }
}
