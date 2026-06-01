import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Composition: dependentRequired

@Suite("JSONSchema dependentRequired")
struct JSONSchemaDependentRequiredTests {
  @Test("dependentRequired — valid when dependency key is absent")
  func depRequiredKeyAbsent() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentRequired": .object([
          "credit_card": .array([.string("number"), .string("cvc")])
        ])
      ])
    )
    let doc: JSON = .object(["name": .string("Alice")])
    #expect(schema.validating(doc).valid)
  }

  @Test("dependentRequired — valid when dependency key is present and required keys are present")
  func depRequiredValid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentRequired": .object([
          "credit_card": .array([.string("number"), .string("cvc")])
        ])
      ])
    )
    let doc: JSON = .object([
      "credit_card": .string("x"), "number": .string("1234"), "cvc": .string("789"),
    ])
    #expect(schema.validating(doc).valid)
  }

  @Test("dependentRequired — invalid when dependency key is present but required keys are missing")
  func depRequiredInvalid() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentRequired": .object([
          "credit_card": .array([.string("number"), .string("cvc")])
        ])
      ])
    )
    let doc: JSON = .object(["credit_card": .string("x"), "number": .string("1234")])
    let result = schema.validating(doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .dependentRequired)
  }

  @Test("dependentRequired — multiple dependency keys")
  func depRequiredMultiple() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentRequired": .object([
          "a": .array([.string("b")]),
          "b": .array([.string("a")]),
        ])
      ])
    )
    let doc: JSON = .object(["a": .string("x")])
    let result = schema.validating(doc)
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .dependentRequired)
    #expect(result.errors.first?.message.contains("b") == true)
  }

  @Test("dependentRequired — two errors when two keys are missing")
  func depRequiredTwoMissing() throws {
    let schema = try JSONSchema(
      schema: .object([
        "dependentRequired": .object([
          "credit_card": .array([.string("number"), .string("cvc")])
        ])
      ])
    )
    let doc: JSON = .object(["credit_card": .string("x")])
    let result = schema.validating(doc)
    #expect(result.errors.count == 2)
    #expect(result.errors.allSatisfy { $0.keyword == .dependentRequired })
  }
}
