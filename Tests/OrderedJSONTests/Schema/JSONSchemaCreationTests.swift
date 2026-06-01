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

  // MARK: - JSONSchemaKeyword typed enum tests

  @Test("JSONSchemaKeyword round-trips through rawValue")
  func keywordRoundTrip() {
    for keyword in JSONSchemaKeyword.allCases {
      let raw = keyword.rawValue
      #expect(!raw.isEmpty)
      let reconstructed = JSONSchemaKeyword(rawValue: raw)
      #expect(reconstructed == keyword)
    }
  }

  @Test("JSONSchemaKeyword subscript works on JSON objects")
  func keywordSubscript() {
    let obj: JSON = .object(["type": .string("object")])
    let val = obj[key: .type]
    #expect(val == .string("object"))
    #expect(val?.stringValue == "object")

    // Missing key returns nil
    let missing = obj[key: .minimum]
    #expect(missing == nil)
  }

  @Test("JSONSchemaKeyword all validation cases are covered")
  func keywordAllValidationCases() {
    let allValidationKeywords: Set<JSONSchemaKeyword> = [
      .type, .properties, .required, .minimum, .maximum,
      .multipleOf, .pattern, .enum, .const, .minLength, .maxLength,
      .allOf, .anyOf, .oneOf, .not, .if, .minItems, .maxItems,
      .uniqueItems, .contains, .minProperties, .maxProperties,
      .propertyNames, .patternProperties, .additionalProperties,
      .items, .exclusiveMinimum, .exclusiveMaximum,
      .format, .dependencies, .additionalItems,
      .dependentSchemas, .dependentRequired, .prefixItems,
      .unevaluatedItems, .unevaluatedProperties,
      .contentMediaType, .contentEncoding, .contentSchema,
      .minContains, .maxContains,
    ]
    #expect(allValidationKeywords == JSONSchema.validationKeywords)
  }

  @Test("keywordCache only stores recognized JSONSchemaKeyword cases")
  func keywordCacheExcludesCustomKeywords() throws {
    let schema = try JSONSchema(
      schema: .object([
        "type": .string("object"),
        "properties": .object([
          "name": .object(["type": .string("string")])
        ]),
        "x-unknown-keyword": .null,
      ])
    )
    let cache = schema.compiled?.keywordCache[""]
    #expect(cache != nil)
    // Known keywords are cached
    #expect(cache?[JSONSchemaKeyword.type] != nil)
    #expect(cache?[JSONSchemaKeyword.properties] != nil)
    // Custom keyword "x-unknown-keyword" has no JSONSchemaKeyword case,
    // so it is excluded from the cache. Keys are JSONSchemaKeyword type.
    #expect(cache?.count == 2)
  }
}
