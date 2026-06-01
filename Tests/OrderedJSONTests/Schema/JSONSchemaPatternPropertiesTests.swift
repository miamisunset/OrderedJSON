import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Object Keywords

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
      result.errors.map(\.keyword).contains(.patternProperties)
        || result.errors.map(\.keyword).contains(.type)
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

// MARK: - PatternProperties Edge Cases

@Suite("JSONSchema patternProperties edge cases")
struct JSONSchemaPatternPropertiesEdgeCasesTests {
  @Test("patternProperties — multiple matching patterns for same key")
  func patternPropertiesMultipleMatches() throws {
    let schema = try JSONSchema(
      schema: .object([
        "patternProperties": .object([
          "^a": .object(["type": .string("string")]),
          "b$": .object(["minimum": .number(.integer(0))]),
        ])
      ])
    )
    // Key "ab" matches both patterns
    let result = schema.validating(.object(["ab": .string("hello")]))
    #expect(result.valid)
  }

  @Test("patternProperties — overlapping patterns produce multiple validations")
  func patternPropertiesOverlapping() throws {
    let schema = try JSONSchema(
      schema: .object([
        "patternProperties": .object([
          "^x": .object(["type": .string("string")]),
          "x$": .object(["minLength": .number(.integer(2))]),
        ])
      ])
    )
    #expect(schema.validating(.object(["x": .string("hi")])).valid)
  }
}
