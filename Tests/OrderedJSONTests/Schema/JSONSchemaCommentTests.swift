import Foundation
import Testing

@testable import OrderedCollections
@testable import OrderedJSON

// MARK: - $comment tests

@Suite("JSONSchema $comment")
struct JSONSchemaCommentTests {
  @Test("$comment — ignored during validation")
  func commentIgnored() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$comment": .string("This is a comment"),
        "type": .string("string"),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }

  @Test("$comment — in subschema")
  func commentInSubschema() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "name": .object([
            "$comment": .string("The person's name"),
            "type": .string("string"),
          ])
        ])
      ])
    )
    #expect(schema.validating(.object(["name": .string("Alice")])).valid)
  }
}
