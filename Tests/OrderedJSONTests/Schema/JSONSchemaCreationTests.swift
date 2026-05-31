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
}
