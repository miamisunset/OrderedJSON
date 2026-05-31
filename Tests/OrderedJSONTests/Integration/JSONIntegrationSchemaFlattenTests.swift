import Foundation
import Testing

@testable import OrderedJSON

@Suite("Integration: schema validate → flatten")
struct JSONIntegrationSchemaFlattenTests {
  @Test("schema validate → flatten: valid document")
  func schemaValidateThenFlatten() throws {
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
    let doc = JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])

    // Validate first
    let valid = try schema.validate(doc)
    #expect(valid)

    // Then flatten — no crash
    let flat = doc.flatten()
    #expect(flat["/name"] == JSON.string("Alice"))
    #expect(flat["/age"] == JSON.number(.integer(30)))

    // Unflatten back
    let restored = try flat.unflatten()
    // Note: flatten/unflatten reorders keys by path order.
    #expect(restored["name"] == .string("Alice"))
    #expect(restored["age"] == .number(.integer(30)))
  }

  @Test("schema validate → flatten: invalid document")
  func schemaInvalidThenFlatten() throws {
    let schemaJSON = try JSON.parse(
      """
      {
        "type": "object",
        "properties": {
          "age": {"type": "integer", "minimum": 0}
        },
        "required": ["age"]
      }
      """)
    let schema = try JSONSchema(schema: schemaJSON)
    let doc = JSON.object(["age": .number(.integer(-1))])

    // Validate should fail
    let result = schema.validating(doc)
    #expect(!result.valid)

    // Flatten should still work — no crash
    let flat = doc.flatten()
    #expect(flat["/age"] == JSON.number(.integer(-1)))

    // Unflatten back — doc has single key, so ordering is deterministic
    let restored = try flat.unflatten()
    #expect(restored == doc)
  }

  @Test("schema validate → flatten: complex nested document")
  func schemaComplexThenFlatten() throws {
    let schemaJSON = try JSON.parse(
      """
      {
        "type": "object",
        "properties": {
          "data": {
            "type": "object",
            "properties": {
              "id": {"type": "integer"},
              "tags": {"type": "array", "items": {"type": "string"}}
            },
            "required": ["id"]
          }
        },
        "required": ["data"]
      }
      """)
    let schema = try JSONSchema(schema: schemaJSON)
    let doc = try JSON.parse(
      """
      {"data": {"id": 1, "tags": ["admin", "user"], "extra": "ignored"}}
      """)

    // Valid
    #expect(try schema.validate(doc))

    // Flatten and unflatten
    let flat = doc.flatten()
    let restored = try flat.unflatten()
    // Note: flatten/unflatten reorders keys by path order.
    // Verify values match individually.
    #expect(restored["data"]?["id"] == .number(.integer(1)))
    #expect(restored["data"]?["tags"] == JSON.array([.string("admin"), .string("user")]))
    #expect(restored["data"]?["extra"] == .string("ignored"))
  }

  @Test("schema validate → flatten → re-validate: no state corruption")
  func schemaValidateFlattenReValidate() throws {
    let schemaJSON = try JSON.parse(
      """
      {
        "type": "object",
        "properties": {
          "x": {"type": "integer"}
        },
        "required": ["x"]
      }
      """)
    let schema = try JSONSchema(schema: schemaJSON)
    let doc1 = JSON.object(["x": .number(.integer(1))])
    let doc2 = JSON.object(["x": .number(.integer(2))])

    // Validate doc1
    #expect(try schema.validate(doc1))

    // Flatten doc2
    let flat2 = doc2.flatten()
    #expect(flat2["/x"] == JSON.number(.integer(2)))

    // Validate doc1 again — schema state should be unchanged
    #expect(try schema.validate(doc1))
  }
}
