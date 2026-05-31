import Foundation
import Testing

@testable import OrderedJSON

@Test func readmeSchemaCreating() throws {
  let schemaJSON = try JSON.parse(
    """
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer", "minimum": 0}
      },
      "required": ["name"]
    }
    """)

  let schema = try JSONSchema(schema: schemaJSON)
  #expect(schema.isValid(JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])))

  // Explicit draft
  let schema2 = try JSONSchema(schema: schemaJSON, draft: .draft7)
  #expect(schema2.isValid(JSON.object(["name": .string("Bob"), "age": .number(.integer(25))])))
}

@Test func readmeSchemaValidation() throws {
  let schemaJSON = try JSON.parse(
    """
    {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer", "minimum": 0}
      },
      "required": ["name"]
    }
    """)
  let schema = try JSONSchema(schema: schemaJSON)
  let document = JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])

  // validate() throws on first error, returns true on success
  let valid = try schema.validate(document)
  #expect(valid)

  // validating() returns VerboseResult (never throws)
  let result = schema.validating(document)
  #expect(result.valid)

  // isValid() boolean check
  #expect(schema.isValid(document))

  // Access errors
  for error in result.errors {
    #expect(error.keyword != "")
  }

  // throwOnError doesn't throw for valid
  try result.throwOnError()
}

@Test func readmeSchemaDrafts() throws {
  #expect(JSONSchema.Draft.draft7 == .draft7)
  #expect(JSONSchema.Draft.draft202012 == .draft202012)
  #expect(JSONSchema.Draft.auto == .auto)
}

@Test func readmeSchemaFormatOptions() throws {
  var formatOptions = JSONSchemaFormatOptions()
  formatOptions.disable(.email)
  #expect(formatOptions.isEnabled(.email) == false)
  formatOptions.enable(.email)
  #expect(formatOptions.isEnabled(.email))
  #expect(formatOptions.isEnabled(.dateTime))
}

@Test func readmeSchemaOutputModes() throws {
  let schemaJSON = try JSON.parse(
    """
    {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer", "minimum": 0}
      },
      "required": ["name"]
    }
    """)

  let schema = try JSONSchema(schema: schemaJSON, outputMode: .verbose)
  let result = schema.validating(JSON.object(["age": .number(.integer(-1))]))
  #expect(!result.valid)
}

@Test func readmeSchemaInference() throws {
  let instance = try JSON.parse(
    """
    {"name": "Alice", "age": 30, "tags": ["admin", "user"]}
    """)

  let generatedSchema = JSONSchemaGeneration.generate(from: instance)
  #expect(generatedSchema.isObject)

  let schema = try instance.schema()
  #expect(schema.isValid(instance))

  let schema2 = try instance.schema(
    draft: .draft202012,
    formatOptions: JSONSchemaFormatOptions(),
    outputMode: .verbose
  )
  #expect(schema2.isValid(instance))
}
