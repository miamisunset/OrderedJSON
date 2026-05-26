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

  /// Creates a compiled schema from raw JSON.
  /// - Parameter schema: The raw schema JSON.
  init(schema: JSON) {
    self.schemaJSON = schema

    // Collect all annotations by walking the schema tree
    let annotations = CompiledSchema.collectAnnotations(from: schema)

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
  /// - Returns: Collected annotations.
  private static func collectAnnotations(from schema: JSON) -> (
    defs: OrderedDictionary<String, JSON>,
    anchors: OrderedDictionary<String, JSON>,
    dynamicAnchors: OrderedDictionary<String, JSON>
  ) {
    var defs = OrderedDictionary<String, JSON>()
    var anchors = OrderedDictionary<String, JSON>()
    var dynamicAnchors = OrderedDictionary<String, JSON>()

    // Recursively walk the schema tree
    collectAnnotationsRecursive(
      schema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)

    return (defs, anchors, dynamicAnchors)
  }

  /// Recursively walks a schema (or subschema) to collect annotations.
  private static func collectAnnotationsRecursive(
    _ schema: JSON,
    defs: inout OrderedDictionary<String, JSON>,
    anchors: inout OrderedDictionary<String, JSON>,
    dynamicAnchors: inout OrderedDictionary<String, JSON>
  ) {
    guard schema.isObject else { return }

    // Collect $defs at this level
    if let defsJSON = schema["$defs"], defsJSON.isObject {
      guard case .object(let defDict) = defsJSON.storage else { return }
      for (key, value) in defDict {
        defs[key] = value
        // Recurse into the $defs entry itself — it may contain nested annotations
        collectAnnotationsRecursive(
          value, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
      }
    }

    // Collect $anchor at this level
    if let anchorStr = schema["$anchor"]?.stringValue {
      anchors[anchorStr] = schema
    }

    // Collect $dynamicAnchor at this level
    if let dynAnchorStr = schema["$dynamicAnchor"]?.stringValue {
      dynamicAnchors[dynAnchorStr] = schema
    }

    // Recurse into properties subschemas
    if let properties = schema["properties"], properties.isObject {
      guard case .object(let dict) = properties.storage else { return }
      for (_, propSchema) in dict {
        collectAnnotationsRecursive(
          propSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
      }
    }

    // Recurse into items / prefixItems
    if let items = schema["items"], items.isObject {
      collectAnnotationsRecursive(
        items, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }
    if let prefixItems = schema["prefixItems"], prefixItems.isArray {
      for item in prefixItems where item.isObject {
        collectAnnotationsRecursive(
          item, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
      }
    }

    // Recurse into composition keywords
    for keyword in ["allOf", "anyOf", "oneOf"] {
      if let subschemas = schema[keyword], subschemas.isArray {
        for sub in subschemas where sub.isObject {
          collectAnnotationsRecursive(
            sub, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
        }
      }
    }
    if let notSchema = schema["not"], notSchema.isObject {
      collectAnnotationsRecursive(
        notSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }
    if let ifSchema = schema["if"], ifSchema.isObject {
      collectAnnotationsRecursive(
        ifSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }
    if let thenSchema = schema["then"], thenSchema.isObject {
      collectAnnotationsRecursive(
        thenSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }
    if let elseSchema = schema["else"], elseSchema.isObject {
      collectAnnotationsRecursive(
        elseSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }

    // Recurse into patternProperties values
    if let pp = schema["patternProperties"], pp.isObject {
      guard case .object(let patternDict) = pp.storage else { return }
      for (_, patternSchema) in patternDict {
        collectAnnotationsRecursive(
          patternSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
      }
    }

    // Recurse into contains
    if let containsSchema = schema["contains"], containsSchema.isObject {
      collectAnnotationsRecursive(
        containsSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }

    // Recurse into additionalProperties / unevaluatedProperties
    if let ap = schema["additionalProperties"], ap.isObject {
      collectAnnotationsRecursive(
        ap, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }
    if let up = schema["unevaluatedProperties"], up.isObject {
      collectAnnotationsRecursive(
        up, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }

    // Recurse into additionalItems / unevaluatedItems
    if let ai = schema["additionalItems"], ai.isObject {
      collectAnnotationsRecursive(
        ai, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }
    if let ui = schema["unevaluatedItems"], ui.isObject {
      collectAnnotationsRecursive(
        ui, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }

    // Recurse into propertyNames
    if let pn = schema["propertyNames"], pn.isObject {
      collectAnnotationsRecursive(
        pn, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
    }

    // Recurse into dependentSchemas values
    if let depSchemas = schema["dependentSchemas"], depSchemas.isObject {
      guard case .object(let depDict) = depSchemas.storage else { return }
      for (_, depSchema) in depDict {
        collectAnnotationsRecursive(
          depSchema, defs: &defs, anchors: &anchors, dynamicAnchors: &dynamicAnchors)
      }
    }
  }

  /// Resolves a `$ref` pointer against the schema and its `$defs`.
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

    // Check for #/$defs/... — look up in the compiled defs dictionary.
    // This handles $defs entries that may be nested in subschemas,
    // not just at the root level.
    if pointer.hasPrefix("#/$defs/") {
      let defsKey = String(pointer.dropFirst("#/$defs/".count))
      if let target = defs[defsKey] {
        return target
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
