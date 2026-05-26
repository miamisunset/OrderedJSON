import Foundation
import OrderedCollections

// MARK: - Compiled schema

/// A compiled JSON Schema with pre-resolved `$defs`, `$id`, and `$anchor`.
///
/// Compilation walks the raw schema JSON once at init time:
/// - Collects all `$defs` entries from the root and nested subschemas
/// - Collects all `$anchor` and `$dynamicAnchor` declarations
/// - Parses `$id` for base URI resolution
/// - Skips `$comment` during validation
internal struct CompiledSchema: Hashable, Sendable {
  /// The raw schema JSON (kept for un-compiled keyword access).
  let schemaJSON: JSON
  /// Resolved `$defs` entries: key → schema JSON.
  let defs: OrderedDictionary<String, JSON>
  /// The base URI established by `$id` (if present).
  let baseURI: String?
  /// Local anchors from `$anchor` keywords: anchor name → schema JSON.
  let anchors: OrderedDictionary<String, JSON>
  /// Dynamic anchors from `$dynamicAnchor` keywords: anchor name → schema JSON.
  let dynamicAnchors: OrderedDictionary<String, JSON>

  /// Creates a compiled schema from raw JSON, throwing on duplicate
  /// `$anchor` / `$dynamicAnchor` names within the same base URI.
  ///
  /// - Parameter schema: The raw schema JSON.
  /// - Throws: `JSONSchemaError` if duplicate anchors are found.
  init(schema: JSON) throws {
    self.schemaJSON = schema

    // Collect all annotations by walking the schema tree
    let annotations = try CompiledSchema.collectAnnotations(from: schema)

    // Parse $id at the root level
    baseURI = schema["$id"]?.stringValue

    defs = annotations.defs
    anchors = annotations.anchors
    dynamicAnchors = annotations.dynamicAnchors
  }

  /// Collects all `$defs`, `$anchor`, and `$dynamicAnchor` declarations
  /// by recursively walking every subschema in the schema tree.
  ///
  /// - Parameter schema: The schema JSON to scan.
  /// - Throws: `JSONSchemaError` if duplicate anchors are found.
  /// - Returns: Collected annotations.
  private static func collectAnnotations(from schema: JSON) throws -> (
    defs: OrderedDictionary<String, JSON>,
    anchors: OrderedDictionary<String, JSON>,
    dynamicAnchors: OrderedDictionary<String, JSON>
  ) {
    var defs = OrderedDictionary<String, JSON>()
    var anchors = OrderedDictionary<String, JSON>()
    var dynamicAnchors = OrderedDictionary<String, JSON>()

    // Recursively walk the schema tree.
    try collectAnnotationsRecursive(
      schema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)

    return (defs, anchors, dynamicAnchors)
  }

  /// Recursively walks a schema (or subschema) to collect annotations.
  ///
  /// Boolean schemas (`true` / `false`) never contain annotations — the
  /// `guard schema.isObject else { return }` at the top of the function
  /// skips them. This is correct per spec: a boolean schema has no keywords
  /// and therefore no `$defs`, `$anchor`, or `$dynamicAnchor`.
  ///
  /// - Parameter schema: The schema JSON to scan.
  /// - Throws: `JSONSchemaError` if duplicate anchors are found.
  private static func collectAnnotationsRecursive(
    _ schema: JSON,
    defs: inout OrderedDictionary<String, JSON>,
    anchors: inout OrderedDictionary<String, JSON>,
    dynamicAnchors: inout OrderedDictionary<String, JSON>
  ) throws {
    guard schema.isObject else { return }

    // Collect $defs at this level.
    // A $defs entry at /$defs/A whose body contains $defs: { B: ... }
    // will produce both defs["A"] and defs["B"] in the flat dictionary.
    // This is a deviation from per-resource scoping (see $id scoping note
    // below) — future phases should scope defs per base URI.
    if let defsJSON = schema["$defs"], defsJSON.isObject {
      if case .object(let defDict) = defsJSON.storage {
        for (key, value) in defDict {
          defs[key] = value
          try collectAnnotationsRecursive(
            value, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
        }
      }
    }

    // Collect $anchor at this level.
    if let anchorStr = schema["$anchor"]?.stringValue {
      if anchors[anchorStr] != nil {
        throw JSONSchemaError(
          instancePath: "",
          schemaPath: "/$anchor",
          keyword: "$anchor",
          message: "duplicate $anchor '\(anchorStr)' in the same base URI"
        )
      }
      anchors[anchorStr] = schema
    }

    // Collect $dynamicAnchor at this level.
    if let dynAnchorStr = schema["$dynamicAnchor"]?.stringValue {
      if dynamicAnchors[dynAnchorStr] != nil {
        throw JSONSchemaError(
          instancePath: "",
          schemaPath: "/$dynamicAnchor",
          keyword: "$dynamicAnchor",
          message: "duplicate $dynamicAnchor '\(dynAnchorStr)' in the same base URI"
        )
      }
      dynamicAnchors[dynAnchorStr] = schema
    }

    // Recurse into properties subschemas
    if let properties = schema["properties"], properties.isObject {
      if case .object(let dict) = properties.storage {
        for (_, propSchema) in dict {
          try collectAnnotationsRecursive(
            propSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
        }
      }
    }

    // Recurse into items / prefixItems
    if let items = schema["items"], items.isObject {
      try collectAnnotationsRecursive(
        items, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }
    if let prefixItems = schema["prefixItems"], prefixItems.isArray {
      for item in prefixItems where item.isObject {
        try collectAnnotationsRecursive(
          item, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
      }
    }

    // Recurse into composition keywords
    for keyword in ["allOf", "anyOf", "oneOf"] {
      if let subschemas = schema[keyword], subschemas.isArray {
        for sub in subschemas where sub.isObject {
          try collectAnnotationsRecursive(
            sub, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
        }
      }
    }
    if let notSchema = schema["not"], notSchema.isObject {
      try collectAnnotationsRecursive(
        notSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }
    if let ifSchema = schema["if"], ifSchema.isObject {
      try collectAnnotationsRecursive(
        ifSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }
    if let thenSchema = schema["then"], thenSchema.isObject {
      try collectAnnotationsRecursive(
        thenSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }
    if let elseSchema = schema["else"], elseSchema.isObject {
      try collectAnnotationsRecursive(
        elseSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }

    // Recurse into patternProperties values
    if let pp = schema["patternProperties"], pp.isObject {
      if case .object(let patternDict) = pp.storage {
        for (_, patternSchema) in patternDict {
          try collectAnnotationsRecursive(
            patternSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
        }
      }
    }

    // Recurse into contains
    if let containsSchema = schema["contains"], containsSchema.isObject {
      try collectAnnotationsRecursive(
        containsSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }

    // Recurse into additionalProperties / unevaluatedProperties
    if let ap = schema["additionalProperties"], ap.isObject {
      try collectAnnotationsRecursive(
        ap, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }
    if let up = schema["unevaluatedProperties"], up.isObject {
      try collectAnnotationsRecursive(
        up, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }

    // Recurse into additionalItems / unevaluatedItems
    if let ai = schema["additionalItems"], ai.isObject {
      try collectAnnotationsRecursive(
        ai, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }
    if let ui = schema["unevaluatedItems"], ui.isObject {
      try collectAnnotationsRecursive(
        ui, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }

    // Recurse into propertyNames
    if let pn = schema["propertyNames"], pn.isObject {
      try collectAnnotationsRecursive(
        pn, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }

    // Recurse into dependentSchemas values
    if let depSchemas = schema["dependentSchemas"], depSchemas.isObject {
      if case .object(let depDict) = depSchemas.storage {
        for (_, depSchema) in depDict {
          try collectAnnotationsRecursive(
            depSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
        }
      }
    }
  }

  /// Resolves a `$ref` pointer against the schema and its `$defs`.
  ///
  /// Supports deep pointers into nested `$defs`: `#/$defs/myObj/properties/foo`
  /// looks up the head key `myObj` in the compiled `defs` dictionary, then
  /// resolves the tail `/properties/foo` as a JSON Pointer against that
  /// subtree. If the head doesn't match a compiled def, falls back to
  /// resolving the full pointer against the root `schemaJSON`.
  ///
  /// - Parameter pointer: A JSON Pointer string (e.g., `#/$defs/foo`).
  /// - Returns: The resolved schema JSON, or `nil` if the pointer cannot be resolved.
  func resolveRef(_ pointer: String) -> JSON? {
    guard pointer.hasPrefix("#") else { return nil }

    // Root reference # returns the schema itself
    if pointer == "#" {
      return schemaJSON
    }

    // Check for $anchor references: #anchorName (no slash after #)
    if !pointer.hasPrefix("#/") {
      let anchorName = String(pointer.dropFirst())
      return anchors[anchorName]
    }

    // Check for #/$defs/<key> or #/$defs/<key>/<tail> — look up the head
    // in the compiled defs dictionary, then resolve the tail against it.
    if pointer.hasPrefix("#/$defs/") {
      let rest = String(pointer.dropFirst("#/$defs/".count))
      // Split on the first '/' to get head and tail
      if let slashIndex = rest.firstIndex(of: "/") {
        let head = String(rest[rest.startIndex..<slashIndex])
        let tail = String(rest[slashIndex...])  // includes leading '/'
        if let target = defs[head] {
          guard let ptr = try? JSONPointer(tail) else { return nil }
          return ptr.resolve(target)
        }
      } else {
        // No trailing path — direct defs lookup
        if let target = defs[rest] {
          return target
        }
      }
    }

    // Build a JSON Pointer from the fragment (#/foo/bar → /foo/bar).
    // The JSONPointer struct handles RFC 6901 resolution including
    // escape sequences, array index validation, and leading-zero rejection.
    guard let ptr = try? JSONPointer(fragment: pointer) else { return nil }
    return ptr.resolve(schemaJSON)
  }

  /// Resolves a `$dynamicRef` pointer against the dynamic scope.
  ///
  /// Per Draft 2020-12, `$dynamicRef` with a fragment like `#myAnchor`
  /// resolves against the nearest `$dynamicAnchor` with that name in the
  /// validation chain. If no dynamic anchor is found, falls back to normal
  /// `$ref` resolution against the schema's own anchors.
  ///
  /// - Parameters:
  ///   - pointer: The `$dynamicRef` pointer string.
  ///   - dynamicScope: The current stack of dynamic anchor tuples (name, schema),
  ///     innermost first.
  /// - Returns: The resolved schema JSON, or `nil` if unresolvable.
  func resolveDynamicRef(
    _ pointer: String,
    dynamicScope: [(String, JSON)]
  ) -> JSON? {
    guard pointer.hasPrefix("#") else { return nil }

    // Extract the anchor name (the fragment after #).
    // Bare "#" means root pointer (RFC 6901), not a dynamic anchor —
    // it won't match any declared $dynamicAnchor and falls through
    // to static $anchor resolution.
    let anchorName: String
    if pointer == "#" {
      anchorName = ""
    } else {
      anchorName = String(pointer.dropFirst())
    }

    // Check the dynamic scope stack (innermost first)
    for (name, target) in dynamicScope.reversed() {
      if name == anchorName {
        return target
      }
    }

    // Fall back to the schema's own dynamic anchors
    if let target = dynamicAnchors[anchorName] {
      return target
    }

    // Final fallback: treat as normal $ref (static anchor)
    return anchors[anchorName]
  }
}
