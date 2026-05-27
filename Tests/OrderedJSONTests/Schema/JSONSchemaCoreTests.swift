import OrderedCollections
@testable import OrderedJSON
import Testing

// MARK: - Schema Creation

@Suite("JSONSchema creation")
struct JSONSchemaCreationTests {
    @Test("creates schema from valid object")
    func createValidSchema() throws {
        let schema: JSON = .object([
            "type": .string("object"),
            "properties": .object([
                "name": .object(["type": .string("string")]),
            ]),
        ])
        let compiled = try JSONSchema(schema: schema)
        #expect(compiled.draft == .draft202012)
    }

    @Test("throws on non-object schema")
    func nonObjectSchema() throws {
        let schema: JSON = .string("not a schema")
        #expect(throws: JSONSchemaError.self) {
            _ = try JSONSchema(schema: schema)
        }
    }

    @Test("throws on invalid regex pattern at init time")
    func invalidPatternAtInit() throws {
        let schema: JSON = .object([
            "type": .string("string"),
            "pattern": .string("[invalid"),
        ])
        #expect(throws: JSONSchemaError.self) {
            _ = try JSONSchema(schema: schema)
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

// MARK: - Result & Error

@Suite("JSONSchema result and error")
struct JSONSchemaResultTests {
    @Test("result — valid is true when no errors")
    func resultValidTrue() throws {
        let schema = try JSONSchema(schema: .object([:]))
        let result = schema.validation(of: .string("hello"))
        #expect(result.valid)
        #expect(result.errors.isEmpty)
    }

    @Test("result — valid is false when errors")
    func resultValidFalse() throws {
        let schema = try JSONSchema(schema: .object(["type": .string("number")]))
        let result = schema.validation(of: .string("hello"))
        #expect(!result.valid)
        #expect(result.errors.count == 1)
    }

    @Test("error description includes keyword and message")
    func errorDescription() throws {
        let schema = try JSONSchema(schema: .object(["type": .string("number")]))
        let result = schema.validation(of: .string("hello"))
        let desc = try String(describing: #require(result.errors.first))
        #expect(desc.contains("type"))
        #expect(desc.contains("expected"))
    }

    @Test("throwIfInvalid throws on first error")
    func throwIfInvalid() throws {
        let schema = try JSONSchema(schema: .object(["type": .string("number")]))
        let result = schema.validation(of: .string("hello"))
        #expect(throws: JSONSchemaError.self) {
            try result.throwIfInvalid()
        }
    }

    @Test("throwIfInvalid does nothing on valid result")
    func throwIfValidNoop() throws {
        let schema = try JSONSchema(schema: .object([:]))
        let result = schema.validation(of: .string("hello"))
        try result.throwIfInvalid() // should not throw
    }
}

// MARK: - Output mode and verbose errors

@Suite("JSONSchema output mode")
struct JSONSchemaOutputModeTests {
    @Test("OutputMode — basic is default")
    func outputModeDefault() throws {
        let schema = try JSONSchema(schema: .object(["type": .string("string")]))
        #expect(schema.outputMode == .basic)
    }

    @Test("OutputMode — can be set to verbose")
    func outputModeVerbose() throws {
        let schema = try JSONSchema(
            schema: .object(["type": .string("string")]),
            outputMode: .verbose
        )
        #expect(schema.outputMode == .verbose)
    }

    @Test("JSONSchemaError — failedValue and parentSchema are nil by default")
    func errorFailedValueNil() {
        let error = JSONSchemaError(
            instancePath: "", schemaPath: "/type", keyword: "type",
            message: "expected string"
        )
        #expect(error.failedValue == nil)
        #expect(error.parentSchema == nil)
    }

    @Test("JSONSchemaError — failedValue and parentSchema can be set")
    func errorFailedValueSet() {
        let error = JSONSchemaError(
            instancePath: "", schemaPath: "/type", keyword: "type",
            message: "expected string",
            failedValue: .string("hello"),
            parentSchema: .object(["type": .string("number")])
        )
        #expect(error.failedValue == .string("hello"))
        #expect(error.parentSchema == .object(["type": .string("number")]))
    }

    @Test("JSONSchemaError — Hashable with failedValue and parentSchema")
    func errorHashableWithOptional() {
        let e1 = JSONSchemaError(
            instancePath: "", schemaPath: "/type", keyword: "type",
            message: "test", failedValue: .string("x"), parentSchema: nil
        )
        let e2 = JSONSchemaError(
            instancePath: "", schemaPath: "/type", keyword: "type",
            message: "test", failedValue: .string("x"), parentSchema: nil
        )
        #expect(e1 == e2)
        #expect(e1.hashValue == e2.hashValue)
    }

    @Test("VerboseResult — wraps flat errors (basic mode)")
    func verboseResultBasic() throws {
        let schema = try JSONSchema(schema: .object(["type": .string("number")]))
        let result = schema.validation(of: .string("hello"))
        #expect(!result.valid)
        #expect(result.errors.count == 1)
        // Basic mode: verboseErrors is empty
        #expect(result.verboseErrors.isEmpty)
    }

    @Test("VerboseResult — wraps flat errors (verbose mode)")
    func verboseResultVerbose() throws {
        let schema = try JSONSchema(
            schema: .object(["type": .string("number")]),
            outputMode: .verbose
        )
        let result = schema.validation(of: .string("hello"))
        #expect(!result.valid)
        #expect(result.errors.count == 1)
        // Verbose mode: verboseErrors is populated
        #expect(result.verboseErrors.count == 1)
    }

    @Test("VerboseResult — valid result has no errors")
    func verboseResultValid() throws {
        let schema = try JSONSchema(schema: .object([:]))
        let result = schema.validation(of: .string("hello"))
        #expect(result.valid)
        #expect(result.errors.isEmpty)
        #expect(result.verboseErrors.isEmpty)
    }

    @Test("VerboseResult — throwIfInvalid throws on first error")
    func verboseResultThrowIfInvalid() throws {
        let schema = try JSONSchema(schema: .object(["type": .string("number")]))
        let result = schema.validation(of: .string("hello"))
        #expect(throws: JSONSchemaError.self) {
            try result.throwIfInvalid()
        }
    }

    @Test("VerboseError — description without children")
    func verboseErrorDescription() {
        let error = JSONSchemaError(
            instancePath: "", schemaPath: "/type", keyword: "type",
            message: "expected number"
        )
        let verbose = VerboseError(error: error)
        let desc = String(describing: verbose)
        #expect(desc.contains("type"))
        #expect(desc.contains("expected number"))
    }

    @Test("VerboseError — description with children")
    func verboseErrorDescriptionWithChildren() {
        let parent = JSONSchemaError(
            instancePath: "", schemaPath: "/allOf", keyword: "allOf",
            message: "not all subschemas matched"
        )
        let child = JSONSchemaError(
            instancePath: "", schemaPath: "/allOf/0/type", keyword: "type",
            message: "expected string"
        )
        let verbose = VerboseError(error: parent, children: [VerboseError(error: child)])
        let desc = String(describing: verbose)
        #expect(desc.contains("allOf"))
        #expect(desc.contains("expected string"))
        #expect(desc.contains("[")) // children wrapped in brackets
    }

    @Test("buildVerboseErrors — groups errors by schema path segment")
    func buildVerboseErrorsGrouping() throws {
        let schema = try JSONSchema(
            schema: JSON.object([
                "allOf": JSON.array([
                    .object(["type": .string("string")]),
                    .object(["minimum": .number(.integer(100))]),
                ]),
            ]),
            outputMode: .verbose
        )
        let result = schema.validation(of: JSON.number(.integer(42)))
        #expect(!result.valid)
        // allOf produces errors grouped under /allOf
        #expect(result.verboseErrors.count == 1)
        // The parent error should have keyword "allOf" (matched by group key)
        #expect(result.verboseErrors[0].error.keyword == "allOf")
        // There should be child errors for the second failing subschema
        // With short-circuit optimization, only the first failing subschema
        // produces an error — the second is never validated.
        #expect(result.verboseErrors[0].children.count == 0)
    }

    @Test("buildVerboseErrors — keyword mismatch falls back to first error")
    func buildVerboseErrorsKeywordMismatch() throws {
        // Errors with schema paths /foo/bar and /foo/baz share group "foo"
        // but neither has keyword "foo". Should use first alphabetically.
        let e1 = JSONSchemaError(
            instancePath: "", schemaPath: "/foo/bar", keyword: "bar",
            message: "bar failed"
        )
        let e2 = JSONSchemaError(
            instancePath: "", schemaPath: "/foo/baz", keyword: "baz",
            message: "baz failed"
        )
        let schema = try JSONSchema(schema: .object([:]))
        let verbose = schema.buildVerboseErrors(from: [e1, e2])
        #expect(verbose.count == 1)
        #expect(verbose[0].children.count == 1)
    }

    @Test("buildVerboseErrors — single error produces single verbose error")
    func buildVerboseErrorsSingle() throws {
        let schema = try JSONSchema(
            schema: JSON.object(["type": .string("number")]),
            outputMode: .verbose
        )
        let result = schema.validation(of: JSON.string("hello"))
        #expect(result.verboseErrors.count == 1)
        #expect(result.verboseErrors[0].children.isEmpty)
    }
}

// MARK: - validate() throws / isValid()

@Suite("JSONSchema throwing and predicate API")
struct JSONSchemaThrowingAPITests {
    @Test("validate — valid returns true")
    func validateValid() throws {
        let schema = try JSONSchema(schema: .object(["type": .string("string")]))
        #expect(try schema.validate(.string("hello")))
    }

    @Test("validate — invalid throws")
    func validateInvalid() throws {
        let schema = try JSONSchema(schema: .object(["type": .string("number")]))
        #expect(throws: JSONSchemaError.self) {
            try schema.validate(.string("hello"))
        }
    }

    @Test("isValid — returns true for valid document")
    func isValidTrue() throws {
        let schema = try JSONSchema(schema: .object(["type": .string("string")]))
        #expect(schema.isValid(.string("hello")))
    }

    @Test("isValid — returns false for invalid document")
    func isValidFalse() throws {
        let schema = try JSONSchema(schema: .object(["type": .string("number")]))
        #expect(!schema.isValid(.string("hello")))
    }

    @Test("validate — first error thrown, rest are lost")
    func validateFirstError() throws {
        let schema = try JSONSchema(
            schema: .object([
                "type": .string("number"),
                "minimum": .number(.integer(100)),
            ])
        )
        #expect(throws: JSONSchemaError.self) {
            try schema.validate(.number(.integer(5)))
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
            ])
        )

        let person: JSON = .object([
            "name": .string("Alice"),
            "age": .number(.integer(30)),
        ])
        #expect(schema.validation(of: person).valid)
    }

    @Test("full person schema — invalid (missing required)")
    func personMissingRequired() throws {
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
            ])
        )

        let person: JSON = .object(["name": .string("Alice")])
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
                    "age": .object([
                        "type": .string("integer"),
                        "minimum": .number(.integer(0)),
                        "maximum": .number(.integer(200)),
                    ]),
                ]),
                "required": .array([.string("name"), .string("age")]),
            ])
        )

        let person: JSON = .object([
            "name": .string("Alice"),
            "age": .string("thirty"),
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
            ])
        )

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

// MARK: - Review edge cases

@Suite("JSONSchema review edge cases")
struct JSONSchemaReviewEdgeCasesTests {
    @Test("not — with false boolean subschema (passes everything)")
    func notWithFalseSchema() throws {
        let schema = try JSONSchema(schema: .object(["not": .boolean(false)]))
        #expect(schema.validation(of: .string("anything")).valid)
        #expect(schema.validation(of: .number(.integer(42))).valid)
    }

    @Test("not — with true boolean subschema (rejects everything)")
    func notWithTrueSchema() throws {
        let schema = try JSONSchema(schema: .object(["not": .boolean(true)]))
        #expect(!schema.validation(of: .string("anything")).valid)
        #expect(!schema.validation(of: .number(.integer(42))).valid)
        #expect(!schema.validation(of: .null).valid)
    }

    @Test("dependentSchemas — with false value (rejects when key present)")
    func depSchemasWithFalse() throws {
        let schema = try JSONSchema(
            schema: .object([
                "dependentSchemas": .object([
                    "credit_card": .boolean(false),
                ]),
            ])
        )
        #expect(schema.validation(of: .object(["name": .string("Alice")])).valid)
        let result = schema.validation(of: .object(["credit_card": .string("1234")]))
        #expect(!result.valid)
        #expect(result.errors.first?.keyword == "dependentSchemas")
    }

    @Test("if/then — with boolean then (false rejects when if passes)")
    func ifThenBoolean() throws {
        let schema = try JSONSchema(
            schema: .object([
                "if": .object(["type": .string("string")]),
                "then": .boolean(false),
            ])
        )
        #expect(!schema.validation(of: .string("hello")).valid)
        #expect(schema.validation(of: .number(.integer(42))).valid)
    }

    @Test("minLength — multi-scalar grapheme (code point semantics)")
    func minLengthMultiScalar() throws {
        let familyEmoji = "👨‍👩‍👧"
        let schema = try JSONSchema(schema: .object(["minLength": .number(.integer(5))]))
        #expect(schema.validation(of: .string(familyEmoji)).valid)
    }

    @Test("maxLength — multi-scalar grapheme (code point semantics)")
    func maxLengthMultiScalar() throws {
        let familyEmoji = "👨‍👩‍👧"
        let schema = try JSONSchema(schema: .object(["maxLength": .number(.integer(4))]))
        #expect(!schema.validation(of: .string(familyEmoji)).valid)
    }

    @Test("boolean schema init — true accepts everything")
    func booleanTrueInit() throws {
        let schema = try JSONSchema(schema: .boolean(true))
        #expect(schema.validation(of: .null).valid)
        #expect(schema.validation(of: .boolean(false)).valid)
        #expect(schema.validation(of: .number(.integer(42))).valid)
    }

    @Test("boolean schema init — false rejects everything")
    func booleanFalseInit() throws {
        let schema = try JSONSchema(schema: .boolean(false))
        #expect(!schema.validation(of: .null).valid)
        #expect(!schema.validation(of: .string("x")).valid)
    }

    @Test("nested composition — allOf > anyOf > oneOf")
    func nestedComposition() throws {
        let schema = try JSONSchema(
            schema: .object([
                "allOf": .array([
                    .object([
                        "anyOf": .array([
                            .object(["type": .string("string")]),
                            .object(["type": .string("number")]),
                        ]),
                    ]),
                    .object([
                        "oneOf": .array([
                            .object(["minimum": .number(.integer(10))]),
                            .object(["maximum": .number(.integer(0))]),
                        ]),
                    ]),
                ]),
            ])
        )
        #expect(schema.validation(of: .number(.integer(42))).valid)
        #expect(!schema.validation(of: .number(.integer(5))).valid)
    }
}
