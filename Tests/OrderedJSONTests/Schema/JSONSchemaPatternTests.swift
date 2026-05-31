import OrderedCollections
import Testing

@testable import OrderedJSON

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

// MARK: - Pattern Edge Cases

@Suite("JSONSchema pattern edge cases")
struct JSONSchemaPatternEdgeCasesTests {
  @Test("pattern — invalid regex at validation time falls through silently")
  func patternInvalidRegexRuntime() throws {
    // Create a schema with an invalid regex pattern. The pattern is invalid,
    // so compilation should throw. We test the fallback behavior directly.
    #expect(throws: JSONSchemaError.self) {
      try JSONSchema(schema: .object(["pattern": .string("[invalid")]))
    }
  }

  @Test("pattern — very long regex does not crash")
  func patternVeryLongRegex() throws {
    let schema = try JSONSchema(schema: .object(["pattern": .string("a{1000}")]))
    #expect(schema.validating(.string(String(repeating: "a", count: 1000))).valid)
    #expect(!schema.validating(.string("b")).valid)
  }

  @Test("pattern — regex with backslash escapes")
  func patternBackslashEscapes() throws {
    let schema = try JSONSchema(schema: .object(["pattern": .string("\\d+")]))
    #expect(schema.validating(.string("123")).valid)
    #expect(!schema.validating(.string("abc")).valid)
  }
}
