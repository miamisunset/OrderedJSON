import Foundation
import Testing

@testable import OrderedCollections
@testable import OrderedJSON

// MARK: - CompiledSchema tests

@Suite("CompiledSchema")
struct CompiledSchemaTests {
  @Test("compiled — parses $defs")
  func compiledDefs() throws {
    let schema: JSON = .object([
      "$defs": .object([
        "foo": .object(["type": .string("string")]),
        "bar": .object(["type": .string("number")]),
      ]),
      "type": .string("object"),
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.defs["foo"]?.isObject == true)
    #expect(compiled.resources[""]?.defs["bar"]?.isObject == true)
    #expect(compiled.resources[""]?.defs.count == 2)
  }

  @Test("compiled — no $defs yields empty dict")
  func compiledNoDefs() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.defs.isEmpty == true)
  }

  @Test("compiled — parses $id")
  func compiledId() throws {
    let schema: JSON = .object([
      "$id": .string("https://example.com/schema.json"),
      "type": .string("object"),
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(
      compiled.resources["https://example.com/schema.json"]?.baseURI
        == "https://example.com/schema.json"
    )
  }

  @Test("compiled — no $id yields nil")
  func compiledNoId() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.baseURI == "")
  }

  @Test("compiled — parses $anchor")
  func compiledAnchor() throws {
    let schema: JSON = .object([
      "$anchor": .string("myAnchor"),
      "type": .string("object"),
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.anchors["myAnchor"]?.isObject == true)
  }

  @Test("compiled — no $anchor yields empty")
  func compiledNoAnchor() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.anchors.isEmpty == true)
  }

  @Test("compiled — resolveRef with $anchor")
  func resolveAnchor() throws {
    let schema: JSON = .object([
      "$anchor": .string("myAnchor"),
      "type": .string("string"),
    ])
    let compiled = try CompiledSchema(schema: schema)
    let resolved = compiled.resolveRef("#myAnchor")?.schema
    #expect(resolved != nil)
    #expect(resolved?.isObject == true)
  }

  @Test("compiled — resolveRef $defs")
  func resolveDefs() throws {
    let schema: JSON = .object([
      "$defs": .object([
        "stringType": .object(["type": .string("string")])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    let resolved = compiled.resolveRef("#/$defs/stringType")?.schema
    #expect(resolved != nil)
    #expect(resolved?.isObject == true)
  }

  @Test("compiled — resolveRef root")
  func resolveRoot() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = try CompiledSchema(schema: schema)
    let resolved = compiled.resolveRef("#")?.schema
    #expect(resolved != nil)
    #expect(resolved?.isObject == true)
  }

  @Test("compiled — resolveRef non-existent returns nil")
  func resolveMissing() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resolveRef("#/foo") == nil)
    #expect(compiled.resolveRef("#/$defs/nonexistent") == nil)
  }

  @Test("compiled — resolveRef external (non-#) returns nil")
  func resolveExternal() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resolveRef("https://example.com/schema.json#/foo") == nil)
  }
}
