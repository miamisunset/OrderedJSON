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
    if let r = compiled.resources[""] { #expect(r.defs.count == 2) } else { #expect(false) }
  }

  @Test("compiled — no $defs yields empty dict")
  func compiledNoDefs() throws {
    let schema: JSON = .object(["type": .string("object")])
    let compiled = try CompiledSchema(schema: schema)
    if let r = compiled.resources[""] { #expect(r.defs.isEmpty) } else { #expect(false) }
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
        == "https://example.com/schema.json")
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
    if let r = compiled.resources[""] { #expect(r.anchors.isEmpty) } else { #expect(false) }
  }

  @Test("compiled — resolveRef with $anchor")
  func resolveAnchor() throws {
    let schema: JSON = .object([
      "$anchor": .string("myAnchor"),
      "type": .string("string"),
    ])
    let compiled = try CompiledSchema(schema: schema)
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
      ]))
    let result = schema.validation(of: .string("hello"))
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
    if let resource = compiled.resources[""] {
      #expect(resource.defs.count >= 1)
    } else {
      #expect(false, "expected root resource")
    }
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
    let resolved = compiled.resolveRef("#/$defs/stringType")
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
      ]))
    #expect(schema.validation(of: .string("hello")).valid)
    #expect(!schema.validation(of: .number(.integer(42))).valid)
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
    let resolved = compiled.resolveRef("#/$defs/myObj/properties/name")
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
    let resolved = compiled.resolveRef("#/$defs/nestedDef/properties/deepKey")
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
    do {
      let _ = try CompiledSchema(schema: schema)
      #expect(false, "Expected throw but succeeded")
    } catch {
      #expect(true)
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
    do {
      let _ = try CompiledSchema(schema: schema)
      #expect(false, "Expected throw but succeeded")
    } catch {
      #expect(true)
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
      compiled.resources[""]?.anchors["same"] == compiled.resources[""]?.dynamicAnchors["same"])
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
      ]))
    #expect(schema.validation(of: .object(["child": .object([:])])).valid)
  }

  // MARK: - Duplicate $defs keys are silently overwritten (deviation)

  @Test("compiled — duplicate $defs key silently overwritten (known deviation)")
  func duplicateDefsOverwritten() throws {
    // This is a known deviation: nested $defs with the same key name
    // are flat-collected and the last one wins. Per-resource scoping
    // is deferred to Phase 4d ($id scoping).
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
    let compiled = try! CompiledSchema(schema: schema)
    // The last one visited wins — in this case the inner one after
    // the root defs (walk order: root first, then properties).
    #expect(compiled.resources[""]?.defs["sameKey"]?["type"]?.stringValue == "number")
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
    let resolved = compiled.resolveRef("#/$defs/a~1b")
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
    let resolved = compiled.resolveRef("#/$defs/c~0d/properties/name")
    #expect(resolved != nil)
    #expect(resolved?["type"]?.stringValue == "string")
  }

  // MARK: - init throwing API change

  @Test("JSONSchema — init throws on duplicate $anchor")
  func jsonSchemaInitThrowsOnDuplicateAnchor() throws {
    do {
      let _ = try JSONSchema(
        schema: .object([
          "$anchor": .string("dup"),
          "properties": .object([
            "child": .object(["$anchor": .string("dup")])
          ]),
        ]))
      #expect(false, "Expected throw but succeeded")
    } catch {
      #expect(true)
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
      ]))
    #expect(schema.validation(of: .object(["child": .object(["x": .number(.integer(42))])])).valid)
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
      ]))
    #expect(schema.validation(of: .string("hello")).valid)
    #expect(!schema.validation(of: .number(.integer(42))).valid)
  }

  @Test("duplicate $id throws at init")
  func duplicateIdThrows() throws {
    do {
      let _ = try JSONSchema(
        schema: .object([
          "$id": .string("/dup"),
          "properties": .object([
            "child": .object(["$id": .string("/dup")])
          ]),
        ]))
      #expect(false, "Expected throw but succeeded")
    } catch {
      #expect(true)
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
      ]))
    // #rootAnchor from inside /child should NOT resolve to root's anchor
    // because the current resource URI is "/child", and /child has no
    // anchor named "rootAnchor". The $ref should fail.
    #expect(!schema.validation(of: .object(["child": .object([:])])).valid)
  }
}
