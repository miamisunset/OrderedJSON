import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Schema Creation

@Suite("JSONSchema creation")
struct JSONSchemaCreationTests {

  @Test("creates schema from valid object")
  func createValidSchema() throws {
    let schema: JSON = .object([
      "type": .string("object"),
      "properties": .object([
        "name": .object(["type": .string("string")])
      ]),
    ])
    let compiled = try JSONSchema(schema: schema)
    #expect(compiled.draft == .draft202012)
  }

  @Test("throws on non-object schema")
  func nonObjectSchema() throws {
    let schema: JSON = .string("not a schema")
    #expect(throws: JSONSchemaError.self) {
      let _ = try JSONSchema(schema: schema)
    }
  }

  @Test("throws on invalid regex pattern at init time")
  func invalidPatternAtInit() throws {
    let schema: JSON = .object([
      "type": .string("string"),
      "pattern": .string("[invalid"),
    ])
    #expect(throws: JSONSchemaError.self) {
      let _ = try JSONSchema(schema: schema)
    }
  }

  @Test("auto-detect draft 7 from $schema")
  func detectDraft7() throws {
    let schema: JSON = .object([
      "$schema": .string("http://json-schema.org/draft-07/schema#"),
      "type": .string("string"),
    ])
    let compiled = try JSONSchema(schema: schema)
    #expect(compiled.draft == .draft7)
  }

  @Test("auto-detect draft 2020-12 from $schema")
  func detectDraft202012() throws {
    let schema: JSON = .object([
      "$schema": .string("https://json-schema.org/draft/2020-12/schema"),
      "type": .string("string"),
    ])
    let compiled = try JSONSchema(schema: schema)
    #expect(compiled.draft == .draft202012)
  }

  @Test("auto-detect defaults to 2020-12 without $schema")
  func detectDefault() throws {
    let schema: JSON = .object(["type": .string("string")])
    let compiled = try JSONSchema(schema: schema)
    #expect(compiled.draft == .draft202012)
  }

  @Test("explicit draft 7")
  func explicitDraft7() throws {
    let schema: JSON = .object(["type": .string("string")])
    let compiled = try JSONSchema(schema: schema, draft: .draft7)
    #expect(compiled.draft == .draft7)
  }

  @Test("explicit draft 2020-12")
  func explicitDraft202012() throws {
    let schema: JSON = .object(["type": .string("string")])
    let compiled = try JSONSchema(schema: schema, draft: .draft202012)
    #expect(compiled.draft == .draft202012)
  }
}

// MARK: - Type Validation

@Suite("JSONSchema type validation")
struct JSONSchemaTypeTests {

  @Test("type string — valid")
  func typeStringValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    let result = schema.validation(of: .string("hello"))
    #expect(result.valid)
  }

  @Test("type string — invalid (number)")
  func typeStringInvalid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    let result = schema.validation(of: .number(.integer(42)))
    #expect(!result.valid)
    #expect(result.errors.count == 1)
    #expect(result.errors.first?.keyword == "type")
  }

  @Test("type integer — valid")
  func typeIntegerValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("integer")]))
    let result = schema.validation(of: .number(.integer(42)))
    #expect(result.valid)
  }

  @Test("type integer — invalid (float)")
  func typeIntegerInvalidFloat() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("integer")]))
    let result = schema.validation(of: .number(.float(3.14)))
    #expect(!result.valid)
  }

  @Test("type number — accepts integer")
  func typeNumberAcceptsInteger() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    let result = schema.validation(of: .number(.integer(42)))
    #expect(result.valid)
  }

  @Test("type number — accepts float")
  func typeNumberAcceptsFloat() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    let result = schema.validation(of: .number(.float(3.14)))
    #expect(result.valid)
  }

  @Test("type boolean — valid")
  func typeBooleanValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("boolean")]))
    let result = schema.validation(of: .boolean(true))
    #expect(result.valid)
  }

  @Test("type null — valid")
  func typeNullValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("null")]))
    let result = schema.validation(of: .null)
    #expect(result.valid)
  }

  @Test("type object — valid")
  func typeObjectValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("object")]))
    let result = schema.validation(of: .object([:]))
    #expect(result.valid)
  }

  @Test("type array — valid")
  func typeArrayValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("array")]))
    let result = schema.validation(of: .array([]))
    #expect(result.valid)
  }

  @Test("type array of strings — valid")
  func typeArrayOfStrings() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .array([.string("string"), .string("number")])
      ]))
    #expect(schema.validation(of: .string("hello")).valid)
    #expect(schema.validation(of: .number(.integer(42))).valid)
  }

  @Test("type array of strings — invalid")
  func typeArrayOfStringsInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .array([.string("string"), .string("number")])
      ]))
    let result = schema.validation(of: .boolean(true))
    #expect(!result.valid)
  }
}

// MARK: - Properties Validation

@Suite("JSONSchema properties validation")
struct JSONSchemaPropertiesTests {

  @Test("properties — valid nested")
  func propertiesValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("object"),
        "properties": .object([
          "name": .object(["type": .string("string")]),
          "age": .object(["type": .string("integer")]),
        ]),
      ]))
    let doc: JSON = .object([
      "name": .string("Alice"),
      "age": .number(.integer(30)),
    ])
    let result = schema.validation(of: doc)
    #expect(result.valid)
  }

  @Test("properties — invalid nested")
  func propertiesInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("object"),
        "properties": .object([
          "name": .object(["type": .string("string")])
        ]),
      ]))
    let doc: JSON = .object([
      "name": .number(.integer(42))  // wrong type
    ])
    let result = schema.validation(of: doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "type")
  }

  @Test("properties — missing key doesn't fail (not required)")
  func propertiesMissingKey() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("object"),
        "properties": .object([
          "name": .object(["type": .string("string")]),
          "age": .object(["type": .string("integer")]),
        ]),
      ]))
    let doc: JSON = .object([
      "name": .string("Alice")
      // age is missing — should not fail
    ])
    let result = schema.validation(of: doc)
    #expect(result.valid)
  }

  @Test("properties — non-object value skips validation")
  func propertiesNonObject() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "name": .object(["type": .string("string")])
        ])
      ]))
    let doc: JSON = .string("not an object")
    let result = schema.validation(of: doc)
    #expect(result.valid)
  }
}

// MARK: - Required Validation

@Suite("JSONSchema required validation")
struct JSONSchemaRequiredTests {

  @Test("required — valid when all present")
  func requiredValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("object"),
        "required": .array([.string("name"), .string("age")]),
      ]))
    let doc: JSON = .object([
      "name": .string("Alice"),
      "age": .number(.integer(30)),
    ])
    let result = schema.validation(of: doc)
    #expect(result.valid)
  }

  @Test("required — fails when missing")
  func requiredMissing() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("object"),
        "required": .array([.string("name"), .string("age")]),
      ]))
    let doc: JSON = .object([
      "name": .string("Alice")
    ])
    let result = schema.validation(of: doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "required")
  }

  @Test("required — null is valid (spec: presence only)")
  func requiredNullValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("object"),
        "required": .array([.string("name")]),
      ]))
    let doc: JSON = .object([
      "name": .null
    ])
    // Per JSON Schema spec, `required` checks key *presence*, not value.
    // An explicit `null` satisfies required.
    let result = schema.validation(of: doc)
    #expect(result.valid)
  }

  @Test("required — non-object skips validation")
  func requiredNonObject() throws {
    let schema = try JSONSchema(
      schema: .object([
        "required": .array([.string("name")])
      ]))
    let doc: JSON = .string("not an object")
    let result = schema.validation(of: doc)
    #expect(result.valid)
  }
}

// MARK: - Numeric Bounds

@Suite("JSONSchema numeric bounds")
struct JSONSchemaNumericTests {

  @Test("minimum — valid")
  func minimumValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "minimum": .number(.integer(0)),
      ]))
    let result = schema.validation(of: .number(.integer(5)))
    #expect(result.valid)
  }

  @Test("minimum — invalid")
  func minimumInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "minimum": .number(.integer(0)),
      ]))
    let result = schema.validation(of: .number(.integer(-1)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "minimum")
  }

  @Test("maximum — valid")
  func maximumValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "maximum": .number(.integer(100)),
      ]))
    let result = schema.validation(of: .number(.integer(50)))
    #expect(result.valid)
  }

  @Test("maximum — invalid")
  func maximumInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "maximum": .number(.integer(100)),
      ]))
    let result = schema.validation(of: .number(.integer(200)))
    #expect(!result.valid)
  }

  @Test("minimum + maximum — valid in range")
  func minMaxBothValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "minimum": .number(.integer(0)),
        "maximum": .number(.integer(100)),
      ]))
    let result = schema.validation(of: .number(.integer(50)))
    #expect(result.valid)
  }

  @Test("minimum + maximum — invalid out of range")
  func minMaxBothInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "minimum": .number(.integer(0)),
        "maximum": .number(.integer(100)),
      ]))
    let result = schema.validation(of: .number(.integer(200)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "maximum")
  }

  @Test("minimum with Int64.max preserves precision")
  func minimumInt64Precision() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("integer"),
        "minimum": .number(.integer(Int64.max)),
      ]))
    let doc: JSON = .number(.integer(Int64.max))
    let result = schema.validation(of: doc)
    #expect(result.valid)

    let doc2: JSON = .number(.integer(Int64.max - 1))
    let result2 = schema.validation(of: doc2)
    #expect(!result2.valid)
  }
}

// MARK: - Exclusive Bounds

@Suite("JSONSchema exclusive bounds")
struct JSONSchemaExclusiveTests {

  @Test("exclusiveMinimum — Draft 2020-12 valid")
  func exclMin202012Valid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "exclusiveMinimum": .number(.integer(0)),
      ]))
    let result = schema.validation(of: .number(.integer(1)))
    #expect(result.valid)
  }

  @Test("exclusiveMinimum — Draft 2020-12 invalid (equal)")
  func exclMin202012InvalidEqual() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "exclusiveMinimum": .number(.integer(0)),
      ]))
    let result = schema.validation(of: .number(.integer(0)))
    #expect(!result.valid)
  }

  @Test("exclusiveMinimum — Draft 7 with boolean true")
  func exclMinDraft7Bool() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "minimum": .number(.integer(0)),
        "exclusiveMinimum": .boolean(true),
      ]), draft: .draft7)
    let result = schema.validation(of: .number(.integer(0)))
    #expect(!result.valid)
  }

  @Test("exclusiveMinimum — Draft 7 with boolean false (allowed)")
  func exclMinDraft7BoolFalse() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "minimum": .number(.integer(0)),
        "exclusiveMinimum": .boolean(false),
      ]), draft: .draft7)
    let result = schema.validation(of: .number(.integer(0)))
    #expect(result.valid)
  }

  @Test("exclusiveMaximum — Draft 2020-12 valid")
  func exclMax202012Valid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "exclusiveMaximum": .number(.integer(100)),
      ]))
    let result = schema.validation(of: .number(.integer(50)))
    #expect(result.valid)
  }

  @Test("exclusiveMaximum — Draft 2020-12 invalid (equal)")
  func exclMax202012InvalidEqual() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "exclusiveMaximum": .number(.integer(100)),
      ]))
    let result = schema.validation(of: .number(.integer(100)))
    #expect(!result.valid)
  }

  @Test("exclusiveMaximum — Draft 7 with boolean true")
  func exclMaxDraft7Bool() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "maximum": .number(.integer(100)),
        "exclusiveMaximum": .boolean(true),
      ]), draft: .draft7)
    let result = schema.validation(of: .number(.integer(100)))
    #expect(!result.valid)
  }
}

// MARK: - MultipleOf

@Suite("JSONSchema multipleOf")
struct JSONSchemaMultipleOfTests {

  @Test("multipleOf — valid integer")
  func multipleOfValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("integer"),
        "multipleOf": .number(.integer(3)),
      ]))
    let result = schema.validation(of: .number(.integer(9)))
    #expect(result.valid)
  }

  @Test("multipleOf — invalid integer")
  func multipleOfInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("integer"),
        "multipleOf": .number(.integer(3)),
      ]))
    let result = schema.validation(of: .number(.integer(10)))
    #expect(!result.valid)
  }

  @Test("multipleOf — valid float")
  func multipleOfFloat() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "multipleOf": .number(.float(1.5)),
      ]))
    let result = schema.validation(of: .number(.float(4.5)))
    #expect(result.valid)
  }

  @Test("multipleOf — non-number value skips")
  func multipleOfNonNumber() throws {
    let schema = try JSONSchema(
      schema: .object([
        "multipleOf": .number(.integer(2))
      ]))
    let result = schema.validation(of: .string("hello"))
    #expect(result.valid)
  }

  @Test("multipleOf — zero or negative is ignored per spec")
  func multipleOfNonPositive() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("number"),
        "multipleOf": .number(.integer(0)),  // 0 is ignored
      ]))
    let result = schema.validation(of: .number(.integer(5)))
    #expect(result.valid)
  }
}

// MARK: - Pattern

@Suite("JSONSchema pattern")
struct JSONSchemaPatternTests {

  @Test("pattern — valid match")
  func patternValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("string"),
        "pattern": .string("^[a-z]+$"),
      ]))
    let result = schema.validation(of: .string("hello"))
    #expect(result.valid)
  }

  @Test("pattern — invalid no match")
  func patternInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("string"),
        "pattern": .string("^[a-z]+$"),
      ]))
    let result = schema.validation(of: .string("HelloWorld"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "pattern")
  }

  @Test("pattern — non-string value skips")
  func patternNonString() throws {
    let schema = try JSONSchema(
      schema: .object([
        "pattern": .string("^[a-z]+$")
      ]))
    let result = schema.validation(of: .number(.integer(42)))
    #expect(result.valid)
  }

  @Test("pattern — invalid regex fails at init time, not at validation")
  func patternInvalidRegex() throws {
    let schemaJSON: JSON = .object([
      "type": .string("string"),
      "pattern": .string("[invalid"),
    ])
    // Should throw at init, not at validate
    #expect(throws: JSONSchemaError.self) {
      let _ = try JSONSchema(schema: schemaJSON)
    }
  }
}

// MARK: - Enum

@Suite("JSONSchema enum")
struct JSONSchemaEnumTests {

  @Test("enum — valid match")
  func enumValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "enum": .array([.number(.integer(1)), .number(.integer(2)), .number(.integer(3))])
      ]))
    let result = schema.validation(of: .number(.integer(2)))
    #expect(result.valid)
  }

  @Test("enum — invalid no match")
  func enumInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "enum": .array([.number(.integer(1)), .number(.integer(2)), .number(.integer(3))])
      ]))
    let result = schema.validation(of: .number(.integer(4)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "enum")
  }

  @Test("enum — string values match")
  func enumString() throws {
    let schema = try JSONSchema(
      schema: .object([
        "enum": .array([.string("a"), .string("b")])
      ]))
    let result = schema.validation(of: .string("a"))
    #expect(result.valid)
  }

  @Test("enum — empty array never matches")
  func enumEmpty() throws {
    let schema = try JSONSchema(
      schema: .object([
        "enum": .array([])
      ]))
    let result = schema.validation(of: .string("a"))
    #expect(!result.valid)
  }

  @Test("enum — integer 1 matches float 1.0 (spec: equal)")
  func enumIntVsFloat() throws {
    let schema = try JSONSchema(
      schema: .object([
        "enum": .array([.number(.float(1.0))])
      ]))
    let result = schema.validation(of: .number(.integer(1)))
    #expect(result.valid)
  }

  @Test("enum — array with integer 1 matches float 1.0")
  func enumArrayIntVsFloat() throws {
    let schema = try JSONSchema(
      schema: .object([
        "enum": .array([.array([.number(.float(1.0))])])
      ]))
    let doc: JSON = .array([.number(.integer(1))])
    let result = schema.validation(of: doc)
    #expect(result.valid)
  }

  @Test("enum — object key order is ignored")
  func enumObjectKeyOrder() throws {
    let schema = try JSONSchema(
      schema: .object([
        "enum": .array([
          .object(["a": .number(.integer(1)), "b": .number(.integer(2))])
        ])
      ]))
    let doc: JSON = .object(["b": .number(.integer(2)), "a": .number(.integer(1))])
    let result = schema.validation(of: doc)
    #expect(result.valid)
  }
}

// MARK: - Const

@Suite("JSONSchema const")
struct JSONSchemaConstTests {

  @Test("const — valid match")
  func constValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "const": .number(.integer(42))
      ]))
    let result = schema.validation(of: .number(.integer(42)))
    #expect(result.valid)
  }

  @Test("const — invalid mismatch")
  func constInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "const": .number(.integer(42))
      ]))
    let result = schema.validation(of: .number(.integer(43)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "const")
  }

  @Test("const — string match")
  func constString() throws {
    let schema = try JSONSchema(
      schema: .object([
        "const": .string("hello")
      ]))
    let result = schema.validation(of: .string("hello"))
    #expect(result.valid)
  }

  @Test("const — object match")
  func constObject() throws {
    let schema = try JSONSchema(
      schema: .object([
        "const": .object(["key": .string("value")])
      ]))
    let result = schema.validation(of: .object(["key": .string("value")]))
    #expect(result.valid)
  }
}

// MARK: - Result & Error

@Suite("JSONSchema result and error")
struct JSONSchemaResultTests {

  @Test("result — valid is true when no errors")
  func resultValid() {
    let result = JSONSchemaResult(valid: true, errors: [])
    #expect(result.valid)
    #expect(result.errors.isEmpty)
  }

  @Test("result — valid is false when errors")
  func resultInvalid() {
    let error = JSONSchemaError(
      instancePath: "", schemaPath: "/type", keyword: "type",
      message: "expected string but found number")
    let result = JSONSchemaResult(valid: false, errors: [error])
    #expect(!result.valid)
    #expect(result.errors.count == 1)
  }

  @Test("error description includes keyword and message")
  func errorDescription() {
    let error = JSONSchemaError(
      instancePath: "/foo", schemaPath: "/properties/foo/type", keyword: "type",
      message: "expected string")
    let desc = error.description
    #expect(desc.contains("[type]"))
    #expect(desc.contains("expected string"))
    #expect(desc.contains("/foo"))
  }

  @Test("throwIfInvalid throws on first error")
  func throwIfInvalid() {
    let error = JSONSchemaError(
      instancePath: "", schemaPath: "/type", keyword: "type", message: "bad")
    let result = JSONSchemaResult(valid: false, errors: [error])
    #expect(throws: JSONSchemaError.self) {
      try result.throwIfInvalid()
    }
  }

  @Test("throwIfInvalid does nothing on valid result")
  func throwIfInvalidValid() throws {
    let result = JSONSchemaResult(valid: true, errors: [])
    try result.throwIfInvalid()  // no throw
  }
}

// MARK: - validate() throws / isValid()

@Suite("JSONSchema throwing and predicate API")
struct JSONSchemaThrowingTests {

  @Test("validate — valid returns true")
  func validateValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    let valid = try schema.validate(.string("hello"))
    #expect(valid)
  }

  @Test("validate — invalid throws")
  func validateInvalid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    #expect(throws: JSONSchemaError.self) {
      try schema.validate(.number(.integer(42)))
    }
  }

  @Test("isValid — returns true for valid document")
  func isValidValid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    #expect(schema.isValid(.string("hello")))
  }

  @Test("isValid — returns false for invalid document")
  func isValidInvalid() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("string")]))
    #expect(!schema.isValid(.number(.integer(42))))
  }

  @Test("validate — first error thrown, rest are lost")
  func validateFirstErrorOnly() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("object"),
        "required": .array([.string("a"), .string("b")]),
      ]))
    // Both "a" and "b" are missing, but validate() only throws the first
    #expect(throws: JSONSchemaError.self) {
      try schema.validate(.object(["c": .string("d")]))
    }
  }
}

// MARK: - Integration

@Suite("JSONSchema integration")
struct JSONSchemaIntegrationTests {

  @Test("full person schema — valid")
  func personValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$schema": .string("https://json-schema.org/draft/2020-12/schema"),
        "type": .string("object"),
        "properties": .object([
          "name": .object(["type": .string("string")]),
          "age": .object([
            "type": .string("integer"),
            "minimum": .number(.integer(0)),
            "maximum": .number(.integer(200)),
          ]),
          "email": .object(["type": .string("string"), "pattern": .string("^[a-zA-Z@.]+$")]),
        ]),
        "required": .array([.string("name"), .string("age")]),
      ]))

    let person: JSON = .object([
      "name": .string("Alice"),
      "age": .number(.integer(30)),
      "email": .string("alice@example.com"),
    ])

    let result = schema.validation(of: person)
    #expect(result.valid)
  }

  @Test("full person schema — invalid (missing required)")
  func personMissingRequired() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("object"),
        "properties": .object([
          "name": .object(["type": .string("string")]),
          "age": .object(["type": .string("integer")]),
        ]),
        "required": .array([.string("name"), .string("age")]),
      ]))

    let person: JSON = .object([
      "name": .string("Alice")
    ])

    let result = schema.validation(of: person)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "required")
  }

  @Test("full person schema — invalid (wrong type)")
  func personWrongType() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("object"),
        "properties": .object([
          "name": .object(["type": .string("string")]),
          "age": .object(["type": .string("integer")]),
        ]),
        "required": .array([.string("name"), .string("age")]),
      ]))

    let person: JSON = .object([
      "name": .string("Alice"),
      "age": .string("thirty"),  // wrong type
    ])

    let result = schema.validation(of: person)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "type")
  }

  @Test("full person schema — invalid (age out of range)")
  func personAgeOutOfRange() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("object"),
        "properties": .object([
          "name": .object(["type": .string("string")]),
          "age": .object([
            "type": .string("integer"),
            "minimum": .number(.integer(0)),
            "maximum": .number(.integer(200)),
          ]),
        ]),
        "required": .array([.string("name"), .string("age")]),
      ]))

    let person: JSON = .object([
      "name": .string("Alice"),
      "age": .number(.integer(300)),
    ])

    let result = schema.validation(of: person)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "maximum")
  }

  @Test("empty schema — passes everything")
  func emptySchema() throws {
    let schema = try JSONSchema(schema: .object([:]))
    #expect(schema.validation(of: .null).valid)
    #expect(schema.validation(of: .boolean(true)).valid)
    #expect(schema.validation(of: .number(.integer(42))).valid)
    #expect(schema.validation(of: .string("hello")).valid)
    #expect(schema.validation(of: .array([.number(.integer(1))])).valid)
    #expect(schema.validation(of: .object(["key": .string("val")])).valid)
  }
}

// MARK: - Boolean Schemas

@Suite("JSONSchema boolean schemas")
struct JSONSchemaBooleanTests {

  @Test("true schema — accepts everything")
  func trueSchema() throws {
    let schema = try JSONSchema(schema: .boolean(true))
    #expect(schema.validation(of: .null).valid)
    #expect(schema.validation(of: .boolean(true)).valid)
    #expect(schema.validation(of: .number(.integer(42))).valid)
    #expect(schema.validation(of: .string("hello")).valid)
    #expect(schema.validation(of: .array([.number(.integer(1))])).valid)
    #expect(schema.validation(of: .object([:])).valid)
  }

  @Test("false schema — rejects everything")
  func falseSchema() throws {
    let schema = try JSONSchema(schema: .boolean(false))
    #expect(!schema.validation(of: .null).valid)
    #expect(!schema.validation(of: .boolean(true)).valid)
    #expect(!schema.validation(of: .number(.integer(42))).valid)
    #expect(!schema.validation(of: .string("hello")).valid)
    #expect(!schema.validation(of: .array([.number(.integer(1))])).valid)
    #expect(!schema.validation(of: .object([:])).valid)
  }

  @Test("boolean schema — error message is 'false'")
  func falseSchemaErrorKeyword() throws {
    let schema = try JSONSchema(schema: .boolean(false))
    let result = schema.validation(of: .string("test"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "false")
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
    let doc: JSON = .string("hello")
    #expect(schema.validation(of: doc).valid)
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
    let doc: JSON = .string("hello")
    let result = schema.validation(of: doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "allOf")
  }

  @Test("allOf — empty array passes")
  func allOfEmpty() throws {
    let schema = try JSONSchema(
      schema: .object(["allOf": .array([])]))
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
    let schema = try JSONSchema(
      schema: .object(["anyOf": .array([])]))
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
    let schema = try JSONSchema(
      schema: .object(["oneOf": .array([])]))
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
      schema: .object([
        "not": .object(["type": .string("number")])
      ]))
    #expect(schema.validation(of: .string("test")).valid)
  }

  @Test("not — invalid when subschema matches")
  func notInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "not": .object(["type": .string("string")])
      ]))
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
    let schema = try JSONSchema(
      schema: .object(["if": .object(["type": .string("number")])]))
    #expect(schema.validation(of: .string("test")).valid)  // if fails, no else, no error
    #expect(schema.validation(of: .number(.integer(42))).valid)  // if passes, no then, no error
  }

  @Test("if/then/else — full conditional")
  func ifThenElseFull() throws {
    let schema = try JSONSchema(
      schema: .object([
        "if": .object(["type": .string("number")]),
        "then": .object(["minimum": .number(.integer(0))]),
        "else": .object(["type": .string("string")]),
      ]))
    #expect(schema.validation(of: .number(.integer(42))).valid)  // if passes → then passes
    #expect(schema.validation(of: .number(.integer(-1))).valid == false)  // if passes → then fails
    #expect(schema.validation(of: .string("test")).valid)  // if fails → else passes
    #expect(schema.validation(of: .boolean(true)).valid == false)  // if fails → else fails
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
          "credit_card": .object([
            "type": .string("object"), "required": .array([.string("number")]),
          ])
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
          "credit_card": .object([
            "required": .array([.string("number")])
          ])
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
          "credit_card": .object([
            "required": .array([.string("number"), .string("cvc")])
          ])
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
    // Both a and b present, each requires the other — valid
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
}
