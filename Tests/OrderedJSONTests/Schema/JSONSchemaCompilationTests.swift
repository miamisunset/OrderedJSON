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
    let compiled = CompiledSchema(schema: schema)
    #expect(compiled.defs["foo"]?.isObject == true)
    #expect(compiled.defs["bar"]?.isObject == true)
    #expect(compiled.defs.count == 2)
  }

  @Test("compiled — no $defs yields empty dict")
  func compiledNoDefs() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = CompiledSchema(schema: schema)
    #expect(compiled.defs.isEmpty)
  }

  @Test("compiled — parses $id")
  func compiledId() throws {
    let schema: JSON = .object([
      "$id": .string("https://example.com/schema.json"),
      "type": .string("object"),
    ])
    let compiled = CompiledSchema(schema: schema)
    #expect(compiled.baseURI == "https://example.com/schema.json")
  }

  @Test("compiled — no $id yields nil")
  func compiledNoId() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = CompiledSchema(schema: schema)
    #expect(compiled.baseURI == nil)
  }

  @Test("compiled — parses $anchor")
  func compiledAnchor() throws {
    let schema: JSON = .object([
      "$anchor": .string("myAnchor"),
      "type": .string("object"),
    ])
    let compiled = CompiledSchema(schema: schema)
    #expect(compiled.anchors["myAnchor"]?.isObject == true)
  }

  @Test("compiled — no $anchor yields empty")
  func compiledNoAnchor() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = CompiledSchema(schema: schema)
    #expect(compiled.anchors.isEmpty)
  }

  @Test("compiled — resolveRef with $anchor")
  func resolveAnchor() throws {
    let schema: JSON = .object([
      "$anchor": .string("myAnchor"),
      "type": .string("string"),
    ])
    let compiled = CompiledSchema(schema: schema)
    let resolved = compiled.resolveRef("#myAnchor")
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
    let compiled = CompiledSchema(schema: schema)
    let resolved = compiled.resolveRef("#/$defs/stringType")
    #expect(resolved != nil)
    #expect(resolved?.isObject == true)
  }

  @Test("compiled — resolveRef root")
  func resolveRoot() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = CompiledSchema(schema: schema)
    let resolved = compiled.resolveRef("#")
    #expect(resolved != nil)
    #expect(resolved?.isObject == true)
  }

  @Test("compiled — resolveRef non-existent returns nil")
  func resolveMissing() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = CompiledSchema(schema: schema)
    #expect(compiled.resolveRef("#/foo") == nil)
    #expect(compiled.resolveRef("#/$defs/nonexistent") == nil)
  }

  @Test("compiled — resolveRef external (non-#) returns nil")
  func resolveExternal() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = CompiledSchema(schema: schema)
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

  @Test("$ref — cycle detection via recursion depth")
  func refCycle() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "node": .object(["$ref": .string("#/$defs/node")])
        ]),
        "$ref": .string("#/$defs/node"),
      ]))
    let result = schema.validation(of: .string("anything"))
    #expect(!result.valid)
    // Depth guard fires with keyword "schema"
    #expect(result.errors.first?.keyword == "schema")
    #expect(result.errors.first?.message.contains("depth") == true)
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

// MARK: - $dynamicRef / $dynamicAnchor tests

@Suite("JSONSchema $dynamicRef")
struct JSONSchemaDynamicRefTests {

  @Test("$dynamicRef — self-referential caught by depth guard")
  func dynamicRefSelfReferential() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$dynamicAnchor": .string("node"),
        "$dynamicRef": .string("#node"),
      ]))
    let result = schema.validation(of: .string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "schema")
  }

  @Test("$dynamicRef — fallback to $anchor creates self-reference")
  func dynamicRefFallbackToAnchor() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$anchor": .string("myAnchor"),
        "$dynamicRef": .string("#myAnchor"),
      ]))
    let result = schema.validation(of: .string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "schema")
  }

  @Test("$dynamicRef — unresolvable produces error")
  func dynamicRefUnresolvable() throws {
    let schema = try JSONSchema(
      schema: .object(["$dynamicRef": .string("#nonexistent")]))
    let result = schema.validation(of: .string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "$dynamicRef")
  }

  @Test("$dynamicAnchor — compiled schema stores it")
  func dynamicAnchorCompiled() throws {
    let schema: JSON = .object([
      "$dynamicAnchor": .string("myDynamic"),
      "type": .string("string"),
    ])
    let compiled = CompiledSchema(schema: schema)
    #expect(compiled.dynamicAnchors["myDynamic"]?.isObject == true)
  }

  @Test("$dynamicRef — via $defs without recursion (single level)")
  func dynamicRefViaDefs() throws {
    // $dynamicRef resolves $dynamicAnchor in the schema's own dynamicAnchors.
    // The allOf subschema creates a self-reference cycle caught by depth guard.
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "target": .object(["type": .string("string")])
        ]),
        "$dynamicAnchor": .string("str"),
        "allOf": .array([
          .object(["$dynamicRef": .string("#str")])
        ]),
      ]))
    let result = schema.validation(of: .string("hello"))
    #expect(!result.valid)
    // Depth guard fires during allOf subschema validation
    #expect(result.errors.first?.keyword == "allOf")
  }

  @Test("$dynamicRef — recursive schema via $defs")
  func dynamicRefRecursive() throws {
    // A recursive schema where a node can contain a child node.
    // Dynamic scope propagates through keyword validators, enabling
    // recursive validation via $dynamicRef/$dynamicAnchor.
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "node": .object([
            "$dynamicAnchor": .string("node"),
            "type": .string("object"),
            "properties": .object([
              "value": .object(["type": .string("string")]),
              "child": .object(["$dynamicRef": .string("#node")]),
            ]),
          ])
        ]),
        "$ref": .string("#/$defs/node"),
      ]))
    let result = schema.validation(
      of: .object([
        "value": .string("parent"),
        "child": .object(["value": .string("child")]),
      ]))
    // Dynamic scope propagates through $ref → $defs/node → properties → child
    #expect(result.valid)
  }
}
