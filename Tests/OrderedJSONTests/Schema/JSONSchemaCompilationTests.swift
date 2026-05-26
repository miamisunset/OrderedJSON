import Foundation
import Testing

@testable import OrderedCollections
@testable import OrderedJSON

// MARK: - JSON Pointer resolution tests

@Suite("JSON Pointer resolution")
struct JSONPointerTests {

  @Test("pointer — root returns self")
  func pointerRoot() throws {
    let json: JSON = .object(["foo": .string("bar")])
    #expect(json.resolve("/") == json)
    #expect(json.resolve("#") == nil)  // must start with /
  }

  @Test("pointer — single segment object")
  func pointerSingleSegment() throws {
    let json: JSON = .object(["foo": .string("bar"), "baz": .number(.integer(42))])
    #expect(json.resolve("/foo") == .string("bar"))
    #expect(json.resolve("/baz") == .number(.integer(42)))
  }

  @Test("pointer — nested object")
  func pointerNested() throws {
    let json: JSON = .object([
      "foo": .object(["bar": .string("baz")])
    ])
    #expect(json.resolve("/foo/bar") == .string("baz"))
  }

  @Test("pointer — array index")
  func pointerArrayIndex() throws {
    let json: JSON = .array([.string("a"), .string("b"), .string("c")])
    #expect(json.resolve("/0") == .string("a"))
    #expect(json.resolve("/2") == .string("c"))
  }

  @Test("pointer — array index out of bounds")
  func pointerArrayOutOfBounds() throws {
    let json: JSON = .array([.string("a")])
    #expect(json.resolve("/1") == nil)
    #expect(json.resolve("/-1") == nil)
  }

  @Test("pointer — non-existent key")
  func pointerMissingKey() throws {
    let json: JSON = .object(["foo": .string("bar")])
    #expect(json.resolve("/bar") == nil)
  }

  @Test("pointer — tilde and slash encoding")
  func pointerEncoding() throws {
    let json: JSON = .object([
      "a~b": .string("tilde"),
      "c/d": .string("slash"),
    ])
    // ~0 represents ~, ~1 represents /
    #expect(json.resolve("/a~0b") == .string("tilde"))
    #expect(json.resolve("/c~1d") == .string("slash"))
  }

  @Test("pointer — no leading slash returns nil")
  func pointerNoLeadingSlash() throws {
    let json: JSON = .object(["foo": .string("bar")])
    #expect(json.resolve("foo") == nil)
    #expect(json.resolve("") == nil)
  }
}

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
    #expect(compiled.defs["foo"]?.isObject == true)
    #expect(compiled.defs["bar"]?.isObject == true)
    #expect(compiled.defs.count == 2)
  }

  @Test("compiled — no $defs yields empty dict")
  func compiledNoDefs() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.defs.isEmpty)
  }

  @Test("compiled — parses $id")
  func compiledId() throws {
    let schema: JSON = .object([
      "$id": .string("https://example.com/schema.json"),
      "type": .string("object"),
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.baseURI == "https://example.com/schema.json")
  }

  @Test("compiled — no $id yields nil")
  func compiledNoId() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.baseURI == nil)
  }

  @Test("compiled — parses $anchor")
  func compiledAnchor() throws {
    let schema: JSON = .object([
      "$anchor": .string("myAnchor"),
      "type": .string("object"),
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.anchors["myAnchor"]?.isObject == true)
  }

  @Test("compiled — no $anchor yields empty")
  func compiledNoAnchor() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.anchors.isEmpty)
  }

  @Test("compiled — resolveRef $defs")
  func resolveDefs() throws {
    let schema: JSON = .object([
      "$defs": .object([
        "stringType": .object(["type": .string("string")])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    let resolved = compiled.resolveRef("#/$defs/stringType")
    #expect(resolved != nil)
    #expect(resolved?.isObject == true)
  }

  @Test("compiled — resolveRef root")
  func resolveRoot() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = try CompiledSchema(schema: schema)
    let resolved = compiled.resolveRef("#")
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

// MARK: - $ref validation tests

@Suite("JSONSchema $ref validation")
struct JSONSchemaRefTests {

  @Test("$ref — resolves $defs reference")
  func refDefs() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "name": .object(["type": .string("string")])
        ]),
        "$ref": .string("#/$defs/name"),
      ]))
    #expect(schema.validation(of: .string("Alice")).valid)
    #expect(!schema.validation(of: .number(.integer(42))).valid)
  }

  @Test("$ref — resolves root reference")
  func refRoot() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "positive": .object(["minimum": .number(.integer(0))])
        ]),
        "allOf": .array([
          .object(["$ref": .string("#/$defs/positive")])
        ]),
      ]))
    #expect(schema.validation(of: .number(.integer(5))).valid)
    #expect(!schema.validation(of: .number(.integer(-1))).valid)
  }

  @Test("$ref — nested in properties")
  func refInProperties() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "stringOrNumber": .object([
            "anyOf": .array([
              .object(["type": .string("string")]),
              .object(["type": .string("number")]),
            ])
          ])
        ]),
        "type": .string("object"),
        "properties": .object([
          "value": .object(["$ref": .string("#/$defs/stringOrNumber")])
        ]),
      ]))
    #expect(schema.validation(of: .object(["value": .string("hello")])).valid)
    #expect(schema.validation(of: .object(["value": .number(.integer(42))])).valid)
    #expect(!schema.validation(of: .object(["value": .boolean(true)])).valid)
  }

  @Test("$ref — boolean schema in $defs")
  func refBooleanDefs() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "alwaysFalse": .boolean(false)
        ]),
        "$ref": .string("#/$defs/alwaysFalse"),
      ]))
    #expect(!schema.validation(of: .string("anything")).valid)
  }

  @Test("$ref — non-existent ref fails validation")
  func refMissing() throws {
    let schema = try JSONSchema(
      schema: .object(["$ref": .string("#/$defs/nonexistent")]))
    let result = schema.validation(of: .string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "$ref")
  }
}

// MARK: - $comment tests

@Suite("JSONSchema $comment")
struct JSONSchemaCommentTests {

  @Test("$comment — ignored during validation")
  func commentIgnored() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$comment": .string("This is a comment"),
        "type": .string("string"),
      ]))
    #expect(schema.validation(of: .string("hello")).valid)
    #expect(!schema.validation(of: .number(.integer(42))).valid)
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
      ]))
    #expect(schema.validation(of: .object(["name": .string("Alice")])).valid)
  }
}
