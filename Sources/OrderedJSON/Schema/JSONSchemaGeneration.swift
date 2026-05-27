import Foundation
import OrderedCollections

/// Generates a JSON Schema from a JSON instance.
///
/// It follows the basic inference rules:
///
/// - `null` → `{"type": "null"}`
/// - `boolean` → `{"type": "boolean"}`
/// - `integer` → `{"type": "integer"}`
/// - `float` → `{"type": "number"}`
/// - `string` → `{"type": "string"}`
/// - `array` → `{"type": "array", "items": <schema of elements>}` (if homogeneous)
///   or `{"type": "array", "prefixItems": [...]}` (if heterogeneous)
/// - `object` → `{"type": "object", "properties": {...}, "required": [...]}`
///
/// - Note: The generated schema is a *structural* schema that matches the
///   exact shape of the input.  It does **not** infer `minimum`/`maximum`
///   from numeric values, `minLength`/`maxLength` from strings, or any
///   semantic constraints.  Use it as a starting point for refinement.
///
/// - Important: This inference is purely structural.  It will not infer
///   format constraints, enum values, or numeric bounds.  For a schema
///   that captures the exact shape of a single instance, this is sufficient;
///   for production schemas you should review and add semantic keywords.
public enum JSONSchemaGeneration {

  /// Generates a JSON Schema (as a `JSON` value) that describes the given
  /// JSON instance.
  ///
  /// - Parameter instance: The JSON instance to analyse.
  /// - Returns: A JSON representation of the inferred schema.
  public static func generate(from instance: JSON) -> JSON {
    infer(instance)
  }

  // MARK: - Internal inference

  private static func infer(_ value: JSON) -> JSON {
    switch value.storage {
    case .null:
      return .object(["type": .string("null")])

    case .boolean:
      return .object(["type": .string("boolean")])

    case .number(let num):
      switch num {
      case .integer:
        return .object(["type": .string("integer")])
      case .float:
        return .object(["type": .string("number")])
      }

    case .string:
      return .object(["type": .string("string")])

    case .array(let elements):
      return inferArray(elements)

    case .object(let dict):
      return inferObject(dict)
    }
  }

  private static func inferArray(_ elements: [JSON]) -> JSON {
    guard !elements.isEmpty else {
      // Empty array: allow any items (boolean true schema)
      return .object([
        "type": .string("array"),
        "items": .boolean(true),
      ])
    }

    // Fast path: if all elements share the same primitive kind, we can
    // avoid the O(n) schema comparison entirely.
    let firstKind = primitiveKind(elements[0])
    var allSameKind = true
    for i in 1..<elements.count {
      if primitiveKind(elements[i]) != firstKind {
        allSameKind = false
        break
      }
    }

    if allSameKind {
      // All elements are the same primitive type → homogeneous
      let schema = infer(elements[0])
      return .object([
        "type": .string("array"),
        "items": schema,
      ])
    }

    // Fall back to full schema comparison for complex types
    let firstSchema = infer(elements[0])
    var allSame = true
    for i in 1..<elements.count {
      let s = infer(elements[i])
      if !JSONSchema.schemaEqual(s, firstSchema) {
        allSame = false
        break
      }
    }

    if allSame {
      return .object([
        "type": .string("array"),
        "items": firstSchema,
      ])
    }

    // Heterogeneous → use prefixItems
    let prefixItems: [JSON] = elements.map { infer($0) }
    return .object([
      "type": .string("array"),
      "prefixItems": .array(prefixItems),
      "items": .boolean(false),
    ])
    // items: false ensures no items beyond the tuple length are allowed.
  }

  /// Returns a simple classification of a JSON value for fast homogeneity
  /// checks.  Values that are not primitive (arrays, objects) all map to
  /// "complex" so that they always fall through to the full comparison.
  private static func primitiveKind(_ value: JSON) -> UInt8 {
    switch value.storage {
    case .null:
      return 0
    case .boolean:
      return 1
    case .number(let n):
      switch n {
      case .integer:
        return 2
      case .float:
        return 3
      }
    case .string:
      return 4
    case .array:
      return 5
    case .object:
      return 6
    }
  }

  private static func inferObject(_ dict: OrderedDictionary<String, JSON>) -> JSON {
    var properties = OrderedDictionary<String, JSON>()
    var required: [JSON] = []

    for (key, value) in dict {
      properties[key] = infer(value)
      // Every key present in the instance is required (strict inference)
      required.append(.string(key))
    }

    return .object([
      "type": .string("object"),
      "properties": .object(properties),
      "required": .array(required),
      "additionalProperties": .boolean(false),
    ])
    // additionalProperties: false ensures no extra keys are allowed.
  }

  /// Two inferred schemas are equal if their JSON representation is equal.
  /// Delegates to `JSONSchema.schemaEqual` which handles cross-type number
  /// comparison and Unicode scalar-level string comparison.
  private static func schemaEqual(_ lhs: JSON, _ rhs: JSON) -> Bool {
    JSONSchema.schemaEqual(lhs, rhs)
  }
}

// MARK: - JSON extension

extension JSON {

  /// Infers a JSON Schema that describes this JSON instance.
  ///
  /// The returned schema is a compiled `JSONSchema` object that can be
  /// used immediately for validation.
  ///
  /// - Parameters:
  ///   - draft: The draft version for the generated schema.
  ///     Defaults to `.draft202012`.
  ///   - formatOptions: Options for format validation.
  ///     Defaults to all enabled.
  ///   - outputMode: The output mode for validation results.
  ///     Defaults to `.basic`.
  /// - Returns: A compiled JSON Schema.
  /// - Throws: `JSONSchemaError` if the generated schema is invalid (should
  ///   not happen for valid instances).  Note that very deeply nested
  ///   instances may cause schema compilation to hit recursion limits;
  ///   if this occurs, split the instance or increase the schema depth.
  public func schema(
    draft: JSONSchema.Draft = .draft202012,
    formatOptions: JSONSchemaFormatOptions = JSONSchemaFormatOptions(),
    outputMode: JSONSchema.OutputMode = .basic
  ) throws -> JSONSchema {
    let schemaJSON = JSONSchemaGeneration.generate(from: self)
    return try JSONSchema(
      schema: schemaJSON,
      draft: draft,
      formatOptions: formatOptions,
      outputMode: outputMode
    )
  }
}
