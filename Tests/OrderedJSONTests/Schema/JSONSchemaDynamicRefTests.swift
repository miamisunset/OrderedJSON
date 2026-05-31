import Foundation
import Testing

@testable import OrderedCollections
@testable import OrderedJSON

// MARK: - $dynamicRef / $dynamicAnchor tests

@Suite("JSONSchema $dynamicRef")
struct JSONSchemaDynamicRefTests {
  @Test("$dynamicRef — self-referential caught by depth guard")
  func dynamicRefSelfReferential() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$dynamicAnchor": .string("node"),
        "$dynamicRef": .string("#node"),
      ])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "schema")
  }

  @Test("$dynamicRef — fallback to $anchor creates self-reference")
  func dynamicRefFallbackToAnchor() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$anchor": .string("myAnchor"),
        "$dynamicRef": .string("#myAnchor"),
      ])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "schema")
  }

  @Test("$dynamicRef — unresolvable produces error")
  func dynamicRefUnresolvable() throws {
    let schema = try JSONSchema(
      schema: .object(["$dynamicRef": .string("#nonexistent")])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == "$dynamicRef")
  }

  @Test("$dynamicAnchor — compiled schema stores it")
  func dynamicAnchorCompiled() throws {
    let schema: JSON = .object([
      "$dynamicAnchor": .string("myDynamic"),
      "type": .string("string"),
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.dynamicAnchors["myDynamic"]?.isObject == true)
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
      ])
    )
    let result = schema.validating(.string("hello"))
    #expect(!result.valid)
    // Depth guard fires during allOf subschema validation
    #expect(result.errors.first?.keyword == "allOf")
  }

  @Test("$dynamicRef — recursive schema via $defs")
  func dynamicRefRecursive() throws {
    // Canonical recursive schema pattern: a node can contain a child node
    // of the same type. $dynamicRef/$dynamicAnchor enables this by
    // propagating the dynamic scope through keyword validators.
    // Instance recursion terminates because deeper nodes don't have a
    // "child" key — no further validation is needed.
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
      ])
    )
    let result = schema.validating(
      .object([
        "value": .string("parent"),
        "child": .object(["value": .string("child")]),
      ])
    )
    // Dynamic scope propagates through $ref → $defs/node → properties → child
    #expect(result.valid)
  }
}
