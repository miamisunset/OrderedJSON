import Foundation
import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Schema Memory / Cyclic $ref

/// Tests for cyclic `$ref` detection and deeply nested schemas:
///   4. Cyclic `$ref` in schemas — no infinite loops
///   5. Deeply nested composition keywords — recursion depth guard
@Suite("Memory/Perf: Schema $ref & Deep Nesting")
struct JSONMemoryPerformanceSchemaTests {

  // MARK: - 4. Cyclic / Deep $ref in Schemas

  @Test("multi-level cyclic $ref (A→B→C→A) caught by depth guard")
  func multiLevelCyclicRef() throws {
    let schema = try JSONSchema(
      schema: JSON.object([
        "$defs": JSON.object([
          "A": JSON.object(["$ref": JSON.string("#/$defs/B")]),
          "B": JSON.object(["$ref": JSON.string("#/$defs/C")]),
          "C": JSON.object(["$ref": JSON.string("#/$defs/A")]),
        ]),
        "$ref": JSON.string("#/$defs/A"),
      ])
    )
    let result = schema.validating(JSON.string("hello"))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .dollarRef || result.errors.first?.keyword == .schemaError)
  }

  @Test("chain of 30 $refs hits recursion depth guard")
  func longRefChainHitsDepthGuard() throws {
    var defs = OrderedDictionary<String, JSON>()
    let defKeys = (0..<30).map { "node\($0)" }
    for i in 0..<29 {
      defs[defKeys[i]] = JSON.object(["$ref": JSON.string("#/$defs/\(defKeys[i + 1])")])
    }
    defs[defKeys[29]] = JSON.object(["$ref": JSON.string("#/$defs/\(defKeys[0])")])
    let schema = try JSONSchema(
      schema: JSON.object([
        "$defs": JSON.object(defs),
        "$ref": JSON.string("#/$defs/\(defKeys[0])"),
      ])
    )
    let result = schema.validating(JSON.string("hello"))
    #expect(!result.valid)
  }

  @Test("deeply nested composition keywords hit recursion guard")
  func deeplyNestedComposition() throws {
    var current: JSON = JSON.object(["type": JSON.string("string")])
    for _ in 0..<30 {
      current = JSON.object(["allOf": JSON.array([current])])
    }
    let schema = try JSONSchema(schema: current)
    let result = schema.validating(JSON.number(.integer(42)))
    #expect(!result.valid)
  }

  @Test("deeply nested properties chain validates correctly")
  func deeplyNestedProperties() throws {
    var current: JSON = JSON.object(["type": JSON.string("string")])
    for i in 0..<19 {
      current = JSON.object(["properties": JSON.object(["nested\(i)": current])])
    }
    let schema = try JSONSchema(schema: current)
    var instance: JSON = JSON.string("leaf")
    for i in 0..<19 {
      instance = JSON.object(["nested\(i)": instance])
    }
    let result = schema.validating(instance)
    #expect(result.valid)
  }

  @Test("deeply nested if/then/else chain")
  func deeplyNestedIfThenElse() throws {
    var current: JSON = JSON.object(["type": JSON.string("string")])
    for _ in 0..<30 {
      current = JSON.object([
        "if": JSON.object(["type": JSON.string("object")]),
        "then": current,
      ])
    }
    let schema = try JSONSchema(schema: current)
    let result = schema.validating(JSON.string("hello"))
    #expect(result.valid)
  }

  @Test("$ref to nested $defs (10 levels)")
  func refToDeeplyNestedDefs() throws {
    var defValue: JSON = JSON.object(["type": JSON.string("string")])
    for i in 0..<10 {
      defValue = JSON.object([
        "type": JSON.string("object"),
        "properties": JSON.object(["nested\(i)": defValue]),
      ])
    }
    let schema = try JSONSchema(
      schema: JSON.object([
        "$defs": JSON.object(["deep": defValue]),
        "$ref": JSON.string("#/$defs/deep"),
      ])
    )
    var instance: JSON = JSON.string("leaf")
    for i in 0..<10 {
      instance = JSON.object(["nested\(i)": instance])
    }
    let result = schema.validating(instance)
    #expect(result.valid)
  }

  @Test("compilation handles deeply nested $defs without crash")
  func compilationHandlesDeeplyNestedDefs() throws {
    var defValue: JSON = JSON.object(["type": JSON.string("string")])
    for _ in 0..<30 {
      defValue = JSON.object(["properties": JSON.object(["a": defValue])])
    }
    let schema = try JSONSchema(
      schema: JSON.object([
        "$defs": JSON.object(["deep": defValue]),
        "type": JSON.string("object"),
      ])
    )
    let result = schema.validating(JSON.object(["a": JSON.string("hello")]))
    #expect(result.valid)
  }

  @Test("deeply nested allOf chain (19 levels) validates correctly")
  func deeplyNestedAllOf() throws {
    // maxRecursionDepth=20, so 19 levels of allOf should fit
    var current: JSON = JSON.object(["type": JSON.string("string")])
    for _ in 0..<19 {
      current = JSON.object(["allOf": JSON.array([current])])
    }
    let schema = try JSONSchema(schema: current)
    #expect(schema.validating(JSON.string("hello")).valid)
    #expect(!schema.validating(JSON.number(.integer(42))).valid)
  }

  @Test("cyclic $ref via allOf (A contains allOf [A])")
  func cyclicRefViaAllOf() throws {
    let schema = try JSONSchema(
      schema: JSON.object([
        "allOf": JSON.array([
          JSON.object(["$ref": JSON.string("#")])
        ])
      ])
    )
    let result = schema.validating(JSON.string("hello"))
    #expect(!result.valid)
  }

  @Test("cyclic $ref via properties — depth guard catches deep nesting")
  func cyclicRefViaPropertiesDeep() throws {
    // Schema: { "properties": { "self": { "$ref": "#" } } }
    // Validate a deeply nested object: {"self": {"self": {"self": ... "hello"}}}
    // Each level triggers $ref → root → properties → $ref → root → ... cycle.
    // Depth guard at 20 should catch this.
    let schema = try JSONSchema(
      schema: JSON.object([
        "properties": JSON.object([
          "self": JSON.object(["$ref": JSON.string("#")])
        ])
      ])
    )
    // Build 25 levels of nested {"self": ...} to hit depth guard
    var instance: JSON = JSON.string("leaf")
    for _ in 0..<25 {
      instance = JSON.object(["self": instance])
    }
    let result = schema.validating(instance)
    #expect(!result.valid)
  }

  @Test("deeply nested anyOf with many alternatives")
  func deeplyNestedAnyOf() throws {
    // anyOf passes if at least one matches — use it to test many alternatives
    var alternatives = [JSON]()
    for _ in 0..<100 {
      alternatives.append(JSON.object(["type": JSON.string("string")]))
    }
    let schema = try JSONSchema(schema: JSON.object(["anyOf": JSON.array(alternatives)]))
    #expect(schema.validating(JSON.string("hello")).valid)
  }
}
