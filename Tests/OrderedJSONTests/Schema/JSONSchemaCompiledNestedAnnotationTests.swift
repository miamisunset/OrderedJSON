import Foundation
import Testing

@testable import OrderedCollections
@testable import OrderedJSON

// MARK: - Nested annotation collection tests

@Suite("CompiledSchema nested annotations")
struct CompiledSchemaNestedAnnotationTests {
  @Test("compiled — collects $defs from properties subschema")
  func nestedDefsInProperties() throws {
    let schema: JSON = .object([
      "properties": .object([
        "inner": .object([
          "$defs": .object([
            "nestedType": .object(["type": .string("string")])
          ]),
          "type": .string("object"),
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.defs["nestedType"]?.isObject == true)
    #expect((compiled.resources[""]?.defs.count ?? 0) >= 1)
  }

  @Test("compiled — collects $anchor from allOf subschema")
  func nestedAnchorInAllOf() throws {
    let schema: JSON = .object([
      "allOf": .array([
        .object([
          "$anchor": .string("myAnchor"),
          "type": .string("string"),
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.anchors["myAnchor"]?.isObject == true)
  }

  @Test("compiled — collects $dynamicAnchor from nested location")
  func nestedDynamicAnchor() throws {
    let schema: JSON = .object([
      "$defs": .object([
        "node": .object([
          "$dynamicAnchor": .string("nestedDynamic"),
          "type": .string("object"),
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.dynamicAnchors["nestedDynamic"]?.isObject == true)
  }

  @Test("compiled — resolves $ref to nested $defs")
  func resolveRefNestedDefs() throws {
    let schema: JSON = .object([
      "properties": .object([
        "inner": .object([
          "$defs": .object([
            "stringType": .object(["type": .string("string")])
          ])
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    let resolved = compiled.resolveRef("#/$defs/stringType")?.schema
    #expect(resolved != nil)
    #expect(resolved?.isObject == true)
  }

  @Test("compiled — both $anchor and $dynamicAnchor same name")
  func bothAnchorTypes() throws {
    let schema: JSON = .object([
      "$anchor": .string("same"),
      "$dynamicAnchor": .string("same"),
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.anchors["same"]?.isObject == true)
    #expect(compiled.resources[""]?.dynamicAnchors["same"]?.isObject == true)
    // They point to the same schema but are stored in separate dicts
  }

  @Test("compiled — deep nesting through anyOf > oneOf > properties")
  func deepNestedAnnotations() throws {
    let schema: JSON = .object([
      "anyOf": .array([
        .object([
          "oneOf": .array([
            .object([
              "properties": .object([
                "deep": .object([
                  "$anchor": .string("deepAnchor"),
                  "$dynamicAnchor": .string("deepDynamic"),
                ])
              ])
            ])
          ])
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.anchors["deepAnchor"]?.isObject == true)
    #expect(compiled.resources[""]?.dynamicAnchors["deepDynamic"]?.isObject == true)
  }

  @Test("compiled — resolves $ref to $defs defined in nested properties")
  func resolveRefNestedDefsValidation() throws {
    let schema = try JSONSchema(
      schema: .object([
        "properties": .object([
          "inner": .object([
            "$defs": .object([
              "stringType": .object(["type": .string("string")])
            ])
          ])
        ]),
        "$ref": .string("#/$defs/stringType"),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }

  // MARK: - Deep $defs pointer tests

  @Test("compiled — resolves deep pointer into nested $defs")
  func resolveRefDeepNestedDefs() throws {
    let schema: JSON = .object([
      "$defs": .object([
        "myObj": .object([
          "properties": .object([
            "name": .object(["type": .string("string")])
          ])
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    let resolved = compiled.resolveRef("#/$defs/myObj/properties/name")?.schema
    #expect(resolved != nil)
    #expect(resolved?.isObject == true)
    // Verify it's the "name" subschema
    #expect(resolved?["type"]?.stringValue == "string")
  }

  @Test("compiled — resolves deep pointer into nested $defs with nested defs")
  func resolveRefDeepNestedDefsWithNesting() throws {
    let schema: JSON = .object([
      "properties": .object([
        "inner": .object([
          "$defs": .object([
            "nestedDef": .object([
              "properties": .object([
                "deepKey": .object(["type": .string("number")])
              ])
            ])
          ])
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    let resolved = compiled.resolveRef("#/$defs/nestedDef/properties/deepKey")?.schema
    #expect(resolved != nil)
    #expect(resolved?["type"]?.stringValue == "number")
  }

  // MARK: - Duplicate anchor tests

  @Test("compiled — throws on duplicate $anchor")
  func duplicateAnchorThrows() throws {
    let schema: JSON = .object([
      "$anchor": .string("dup"),
      "properties": .object([
        "child": .object(["$anchor": .string("dup")])
      ]),
    ])
    #expect(throws: (any Error).self) {
      try CompiledSchema(schema: schema)
    }
  }

  @Test("compiled — throws on duplicate $dynamicAnchor")
  func duplicateDynamicAnchorThrows() throws {
    let schema: JSON = .object([
      "$dynamicAnchor": .string("dup"),
      "properties": .object([
        "child": .object(["$dynamicAnchor": .string("dup")])
      ]),
    ])
    #expect(throws: (any Error).self) {
      try CompiledSchema(schema: schema)
    }
  }

  @Test("compiled — bothAnchorTypes points to same JSON value")
  func bothAnchorTypesSameValue() throws {
    let schema: JSON = .object([
      "$anchor": .string("same"),
      "$dynamicAnchor": .string("same"),
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.anchors["same"]?.isObject == true)
    #expect(compiled.resources[""]?.dynamicAnchors["same"]?.isObject == true)
    // They should be the same JSON value (same schema node)
    #expect(
      compiled.resources[""]?.anchors["same"] == compiled.resources[""]?.dynamicAnchors["same"]
    )
  }

  // MARK: - End-to-end $dynamicRef with nested $dynamicAnchor

  @Test("$dynamicRef — resolves against nested $dynamicAnchor via validation")
  func dynamicRefNestedDynamicAnchor() throws {
    // Schema has $dynamicAnchor in a nested $defs; $dynamicRef should
    // resolve to it when dynamic scope propagates through validation.
    // The $dynamicRef is used inside a properties subschema, not as a
    // direct value of the type keyword.
    let schema = try JSONSchema(
      schema: .object([
        "$defs": .object([
          "node": .object([
            "$dynamicAnchor": .string("node"),
            "type": .string("object"),
            "properties": .object([
              "child": .object(["$dynamicRef": .string("#node")])
            ]),
          ])
        ]),
        "$ref": .string("#/$defs/node"),
      ])
    )
    #expect(schema.validating(.object(["child": .object([:])])).valid)
  }

  // MARK: - Duplicate $defs keys are silently overwritten (deviation)

  @Test("compiled — duplicate $defs key silently overwritten (known deviation)")
  func duplicateDefsOverwritten() throws {
    let schema: JSON = .object([
      "$defs": .object([
        "sameKey": .object(["type": .string("string")])
      ]),
      "properties": .object([
        "inner": .object([
          "$defs": .object([
            "sameKey": .object(["type": .string("number")])
          ])
        ])
      ]),
    ])
    let compiled = try CompiledSchema(schema: schema)
    // The last one visited wins — in this case the inner one after
    // the root defs (walk order: root first, then properties).
    #expect(compiled.resources[""]?.defs["sameKey"]?["type"]?.stringValue == "string")
  }

  // MARK: - Cross-arm anchor separation

  @Test("compiled — $anchor and $dynamicAnchor in different subtrees, same name")
  func crossArmAnchorSeparation() throws {
    // $anchor in one subtree, $dynamicAnchor in another, same name.
    // They go into separate dicts and should not collide.
    let schema: JSON = .object([
      "allOf": .array([
        .object(["$anchor": .string("shared")]),
        .object(["$dynamicAnchor": .string("shared")]),
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources[""]?.anchors["shared"]?.isObject == true)
    #expect(compiled.resources[""]?.dynamicAnchors["shared"]?.isObject == true)
  }

  // MARK: - Deep-pointer head escaping

  @Test("compiled — resolves #/$defs/<key> with escaped / in key")
  func resolveRefDefsKeyWithSlash() throws {
    // $defs key contains '/' which is escaped as ~1 in the pointer
    let schema: JSON = .object([
      "$defs": .object([
        "a/b": .object(["type": .string("string")])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    // Pointer: #/$defs/a~1b  (RFC 6901: / → ~1)
    let resolved = compiled.resolveRef("#/$defs/a~1b")?.schema
    #expect(resolved != nil)
    #expect(resolved?["type"]?.stringValue == "string")
  }

  @Test("compiled — resolves #/$defs/<key>/<tail> with escaped ~ in key")
  func resolveRefDefsKeyWithTilde() throws {
    // $defs key contains '~' which is escaped as ~0 in the pointer
    let schema: JSON = .object([
      "$defs": .object([
        "c~d": .object([
          "properties": .object([
            "name": .object(["type": .string("string")])
          ])
        ])
      ])
    ])
    let compiled = try CompiledSchema(schema: schema)
    // Pointer: #/$defs/c~0d/name  (RFC 6901: ~ → ~0)
    let resolved = compiled.resolveRef("#/$defs/c~0d/properties/name")?.schema
    #expect(resolved != nil)
    #expect(resolved?["type"]?.stringValue == "string")
  }

  // MARK: - init throwing API change

  @Test("JSONSchema — init throws on duplicate $anchor")
  func jsonSchemaInitThrowsOnDuplicateAnchor() throws {
    #expect(throws: (any Error).self) {
      try JSONSchema(
        schema: .object([
          "$anchor": .string("dup"),
          "properties": .object([
            "child": .object(["$anchor": .string("dup")])
          ]),
        ])
      )
    }
  }

  // MARK: - $id scoping tests

  @Test("compiled — same anchor name in different $id resources does not collide")
  func sameAnchorDifferentResources() throws {
    // Two embedded resources with $id: "/a" and $id: "/b",
    // each declaring $anchor: "x". Per spec, anchors are scoped
    // to their resource URI and should not collide.
    let schema: JSON = .object([
      "$id": .string("/root"),
      "$defs": .object([
        "a": .object([
          "$id": .string("/a"),
          "$anchor": .string("x"),
          "type": .string("string"),
        ]),
        "b": .object([
          "$id": .string("/b"),
          "$anchor": .string("x"),
          "type": .string("number"),
        ]),
      ]),
    ])
    // Should not throw — anchors have different resource scopes
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources["/a"]?.anchors["x"]?.isObject == true)
    #expect(compiled.resources["/b"]?.anchors["x"]?.isObject == true)
  }

  @Test("compiled — $defs scoped to resource")
  func defsScopedToResource() throws {
    let schema: JSON = .object([
      "$id": .string("/root"),
      "$defs": .object([
        "A": .object(["type": .string("string")])
      ]),
      "properties": .object([
        "inner": .object([
          "$id": .string("/child"),
          "$defs": .object([
            "B": .object(["type": .string("number")])
          ]),
        ])
      ]),
    ])
    let compiled = try CompiledSchema(schema: schema)
    #expect(compiled.resources["/root"]?.defs["A"]?.isObject == true)
    #expect(compiled.resources["/child"]?.defs["B"]?.isObject == true)
    // $defs["A"] should NOT be visible in /child
    #expect(compiled.resources["/child"]?.defs["A"] == nil)
  }

  // MARK: - $id scoping validation tests

  @Test("$ref from inside embedded $id resource resolves to that resource's $defs")
  func refFromEmbeddedResource() throws {
    // $ref: "#/$defs/A" inside a resource with $id: "/child"
    // should resolve to /child's $defs/A, not /root's $defs/A.
    let schema = try JSONSchema(
      schema: .object([
        "$id": .string("/root"),
        "$defs": .object([
          "A": .object(["type": .string("string")])
        ]),
        "properties": .object([
          "child": .object([
            "$id": .string("/child"),
            "$defs": .object([
              "A": .object(["type": .string("number")])
            ]),
            "properties": .object([
              "x": .object(["$ref": .string("#/$defs/A")])
            ]),
          ])
        ]),
      ])
    )
    #expect(schema.validating(.object(["child": .object(["x": .number(.integer(42))])])).valid)
    // The root resource has $defs/A as string type, but the child resource
    // has $defs/A as number type. The $ref from inside child should use
    // the child's $defs/A, so number(42) should pass.
  }

  @Test("$ref from root still resolves to root's $defs")
  func refFromRootResource() throws {
    // $ref at root level should still use root's $defs
    let schema = try JSONSchema(
      schema: .object([
        "$id": .string("/root"),
        "$defs": .object([
          "A": .object(["type": .string("string")])
        ]),
        "$ref": .string("#/$defs/A"),
      ])
    )
    #expect(schema.validating(.string("hello")).valid)
    #expect(!schema.validating(.number(.integer(42))).valid)
  }

  @Test("duplicate $id throws at init")
  func duplicateIdThrows() throws {
    #expect(throws: (any Error).self) {
      try JSONSchema(
        schema: .object([
          "$id": .string("/dup"),
          "properties": .object([
            "child": .object(["$id": .string("/dup")])
          ]),
        ])
      )
    }
  }

  @Test("anchor from root not reachable via #anchor from inside child resource")
  func anchorNotReachableFromChild() throws {
    // Root has $anchor: "rootAnchor". A child resource with $id should
    // not find it via bare #anchor from inside the child.
    let schema = try JSONSchema(
      schema: .object([
        "$anchor": .string("rootAnchor"),
        "properties": .object([
          "child": .object([
            "$id": .string("/child"),
            "$ref": .string("#rootAnchor"),
          ])
        ]),
      ])
    )
    // #rootAnchor from inside /child should NOT resolve to root's anchor
    // because the current resource URI is "/child", and /child has no
    // anchor named "rootAnchor". The $ref should fail.
    #expect(!schema.validating(.object(["child": .object([:])])).valid)
  }

  // MARK: - relative $id resolution & external ref

  @Test("relative $id — nested child resolves against parent base URI")
  func relativeIdNestedChild() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$id": .string("https://example.com/root"),
        "properties": .object([
          "child": .object([
            "$id": .string("child"),
            "type": .string("string"),
          ])
        ]),
      ])
    )
    // The child resource should have baseURI = "https://example.com/child"
    let compiled = try #require(schema.compiled)
    #expect(compiled.resources["https://example.com/child"]?.scopeSchema.isObject == true)
  }

  @Test("relative $id — absolute URI stays as-is")
  func relativeIdAbsoluteStays() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$id": .string("https://example.com/root"),
        "properties": .object([
          "child": .object([
            "$id": .string("https://other.com/schema"),
            "type": .string("string"),
          ])
        ]),
      ])
    )
    let compiled = try #require(schema.compiled)
    #expect(compiled.resources["https://other.com/schema"]?.scopeSchema.isObject == true)
  }

  @Test("relative $id — network-path URI starts with //")
  func relativeIdNetworkPath() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$id": .string("https://example.com/root"),
        "properties": .object([
          "child": .object([
            "$id": .string("//other.com/schema"),
            "type": .string("string"),
          ])
        ]),
      ])
    )
    let compiled = try #require(schema.compiled)
    // URL(string: "//other.com/schema", relativeTo: base) should produce
    // https://other.com/schema (authority replaced)
    #expect(compiled.resources["https://other.com/schema"]?.scopeSchema.isObject == true)
  }

  @Test("relative $id — child with absolute path /foo/bar")
  func relativeIdAbsolutePath() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$id": .string("https://example.com/root"),
        "properties": .object([
          "child": .object([
            "$id": .string("/foo/bar"),
            "type": .string("string"),
          ])
        ]),
      ])
    )
    let compiled = try #require(schema.compiled)
    // /foo/bar resolved against https://example.com/root → https://example.com/foo/bar
    #expect(compiled.resources["https://example.com/foo/bar"]?.scopeSchema.isObject == true)
  }

  @Test("relative $id — $ref resolves against resolved URI")
  func relativeIdRefResolves() throws {
    // Child resource has $id: "child", resolved to /child (relative to root /root).
    // A $ref from outside should be able to reference /child#.
    let schema = try JSONSchema(
      schema: .object([
        "$id": .string("/root"),
        "$defs": .object([
          "A": .object(["type": .string("string")])
        ]),
        "properties": .object([
          "child": .object([
            "$id": .string("child"),
            "$defs": .object([
              "A": .object(["type": .string("number")])
            ]),
          ]),
          "refTarget": .object(["$ref": .string("/child#/$defs/A")]),
        ]),
      ])
    )
    // /child is the resolved URI (root=/root, child="child" → /child)
    // $ref: "/child#/$defs/A" should resolve to /child's defs["A"]
    let result = schema.validating(
      .object([
        "child": .object([:]),
        "refTarget": .number(.integer(42)),
      ])
    )
    #expect(result.valid)
  }

  @Test("bare URI $ref (no #) resolves to resource root")
  func bareUriRefResolves() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$id": .string("/root"),
        "properties": .object([
          "child": .object([
            "$id": .string("/child"),
            "type": .string("string"),
          ]),
          "refTarget": .object(["$ref": .string("/child")]),
        ]),
      ])
    )
    // $ref: "/child" (no #) should resolve to /child's scope schema (which has type: string)
    // So refTarget must be a string
    let result = schema.validating(
      .object([
        "child": .string("hello"),
        "refTarget": .string("world"),
      ])
    )
    #expect(result.valid)

    // refTarget as number should fail
    let result2 = schema.validating(
      .object([
        "child": .string("hello"),
        "refTarget": .number(.integer(42)),
      ])
    )
    #expect(!result2.valid)
  }

  @Test("bare URI $ref — unresolvable URI fails")
  func bareUriRefUnresolvable() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$id": .string("/root"),
        "properties": .object([
          "badRef": .object(["$ref": .string("/nonexistent")])
        ]),
      ])
    )
    // /nonexistent doesn't match any compiled resource, so $ref should fail
    let result = schema.validating(.object(["badRef": .string("hello")]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .dollarRef)
  }

  @Test("cross-resource anchor isolation — #rootAnchor not reachable from /child")
  func crossResourceAnchorIsolation() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$anchor": .string("rootAnchor"),
        "properties": .object([
          "child": .object([
            "$id": .string("/child"),
            "$ref": .string("#rootAnchor"),
          ])
        ]),
      ])
    )
    // #rootAnchor from inside /child should NOT resolve to root's anchor
    // because the current resource URI is "/child", and /child has no
    // anchor named "rootAnchor". The $ref should fail.
    let result = schema.validating(.object(["child": .object([:])]))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .dollarRef)
  }

  @Test("external pointer with tail — #/$defs/A/properties/x")
  func externalPointerWithTail() throws {
    let schema = try JSONSchema(
      schema: .object([
        "$id": .string("/root"),
        "$defs": .object([
          "A": .object([
            "type": .string("object"),
            "properties": .object([
              "x": .object(["type": .string("string")])
            ]),
          ])
        ]),
        "$ref": .string("#/$defs/A/properties/x"),
      ])
    )
    // #/$defs/A/properties/x should resolve to the x subschema (type: string)
    let result = schema.validating(.string("hello"))
    #expect(result.valid)

    let result2 = schema.validating(.number(.integer(42)))
    #expect(!result2.valid)
  }

  @Test("$dynamicRef inside embedded $id resource — falls back to child's dynamicAnchors")
  func dynamicRefFallbackInsideEmbedded() throws {
    // Root has no $dynamicAnchor with name "childAnchor".
    // Child resource has $dynamicAnchor: "childAnchor" → $defs/numberType (type: number).
    // x has $dynamicRef: "#childAnchor". The dynamic scope at x has no
    // matching frame, so resolveDynamicRef falls back to the current resource's
    // dynamicAnchors table, finding child's "childAnchor" → $defs/numberType → number.
    let schema = try JSONSchema(
      schema: .object([
        "$id": .string("/root"),
        "type": .string("object"),
        "$defs": .object([
          "numberType": .object(["type": .string("number")])
        ]),
        "properties": .object([
          "child": .object([
            "$id": .string("/child"),
            "$defs": .object([
              "numberTarget": .object([
                "$dynamicAnchor": .string("childAnchor"),
                "type": .string("number"),
              ])
            ]),
            "properties": .object([
              "x": .object(["$dynamicRef": .string("#childAnchor")])
            ]),
          ])
        ]),
      ])
    )
    // Root schema: type object. Root's $defs/numberType: type number (not used here).
    // Child resource: $defs/numberTarget has $dynamicAnchor "childAnchor" and type: number.
    // x: $dynamicRef "#childAnchor" → falls back to child's dynamicAnchors["childAnchor"]
    // which points to $defs/numberTarget (type: number). So x must be a number.
    let result = schema.validating(
      .object([
        "child": .object(["x": .number(.integer(42))])
      ])
    )
    #expect(result.valid)

    // x as object should fail (type number expected)
    let result2 = schema.validating(
      .object([
        "child": .object(["x": .object([:])])
      ])
    )
    #expect(!result2.valid)
  }
}
