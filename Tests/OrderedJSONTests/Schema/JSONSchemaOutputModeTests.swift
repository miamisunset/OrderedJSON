import Foundation
import Testing

@testable import OrderedCollections
@testable import OrderedJSON

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
    let result = schema.validating(.string("hello"))
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
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.count == 1)
    // Verbose mode: verboseErrors is populated
    #expect(result.verboseErrors.count == 1)
  }

  @Test("VerboseResult — valid result has no errors")
  func verboseResultValid() throws {
    let schema = try JSONSchema(schema: .object([:]))
    let result = schema.validating(.string("hello"))
    #expect(result.valid)
    #expect(result.errors.isEmpty)
    #expect(result.verboseErrors.isEmpty)
  }

  @Test("VerboseResult — throwOnError throws on first error")
  func verboseResultThrowOnError() throws {
    let schema = try JSONSchema(schema: .object(["type": .string("number")]))
    let result = schema.validating(.string("hello"))
    #expect(throws: JSONSchemaError.self) {
      try result.throwOnError()
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
    #expect(desc.contains("["))  // children wrapped in brackets
  }

  @Test("buildVerboseErrors — groups errors by schema path segment")
  func buildVerboseErrorsGrouping() throws {
    let schema = try JSONSchema(
      schema: JSON.object([
        "allOf": JSON.array([
          .object(["type": .string("string")]),
          .object(["minimum": .number(.integer(100))]),
        ])
      ]),
      outputMode: .verbose
    )
    let result = schema.validating(JSON.number(.integer(42)))
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
    let result = schema.validating(JSON.string("hello"))
    #expect(result.verboseErrors.count == 1)
    #expect(result.verboseErrors[0].children.isEmpty)
  }
}
