import OrderedCollections
import Testing

@testable import OrderedJSON

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
    #expect(schema.validating(person).valid)
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
    let result = schema.validating(person)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .required)
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
    let result = schema.validating(person)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .type)
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
    let result = schema.validating(person)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .maximum)
  }

  @Test("empty schema — passes everything")
  func emptySchema() throws {
    let schema = try JSONSchema(schema: .object([:]))
    #expect(schema.validating(.null).valid)
    #expect(schema.validating(.boolean(true)).valid)
    #expect(schema.validating(.number(.integer(42))).valid)
    #expect(schema.validating(.string("hello")).valid)
    #expect(schema.validating(.array([.number(.integer(1))])).valid)
    #expect(schema.validating(.object(["key": .string("val")])).valid)
  }
}
