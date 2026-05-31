import OrderedCollections
import Testing

@testable import OrderedJSON

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
