import Foundation
import OrderedCollections

// MARK: - Compiled schema

/// A compiled JSON Schema with per-resource (`$id`-scoped) annotation tables.
//
// Compilation walks the raw schema JSON once at init time:
// - Identifies embedded resources via `$id` keywords
// - Collects `$defs`, `$anchor`, `$dynamicAnchor` per resource
// - The root resource (no `$id`) uses an empty-string key
//
// ### Relative `$id` resolution
//
// Per Draft 2020-12 / RFC 3986, a nested `$id` value is resolved against
// its parent resource's base URI to form an absolute URI. For example:
//
// ```json
// {
//   "$id": "https://example.com/root",
//   "properties": {
//     "child": { "$id": "child", ... }
//   }
// }
// ```
//
// The child resource's base URI becomes `https://example.com/child`.
// A subsequent `$ref: "https://example.com/child#"` will match.

struct CompiledSchema: Hashable {
  /// The raw schema JSON (kept for un-compiled keyword access).
  let schemaJSON: JSON
  /// Per-resource annotation tables, keyed by base URI (empty string for root).
  let resources: OrderedDictionary<String, ResourceScope>
  /// Pre-compiled regex patterns for `pattern` and `patternProperties` keywords.
  /// Key is the pattern string; value is a thread-safe regex wrapper.
  let precompiledPatterns: [String: LockedRegex]
  /// Cache of keyword values per subschema, keyed by JSON pointer.
  ///
  /// - Warning: This cache is built **before** `$ref` resolution.  For
  ///   subschemas that are resolved via `$ref`, the cache will contain the
  ///   raw keyword values from the `$ref` node itself (which is just a
  ///   `$ref` string), not the resolved target's keywords.  The `kw`
  ///   function falls back to `subschema[key]` for those nodes, so the
  ///   cache provides no benefit for `$ref`-targeted subschemas.
  ///   Consider building the keyword cache **after** `$ref` resolution,
  ///   or at least caching resolved keyword values.
  let keywordCache: [String: [String: JSON]]

  /// Creates a compiled schema from raw JSON.
  /// - Parameter schema: The raw schema JSON.
  /// - Throws: `JSONSchemaError` if duplicate anchors are found.
  init(schema: JSON) throws {
    schemaJSON = schema
    resources = try CompiledSchema.collectResources(from: schema)
    precompiledPatterns = CompiledSchema.compilePatterns(from: schema)
    keywordCache = CompiledSchema.buildKeywordCache(from: schema)
  }

  /// Keyword names whose values may be subschemas to recurse into for
  /// pattern collection and keyword cache building.
  private static let subschemaKeywords: [String] = [
    "items", "allOf", "anyOf", "oneOf", "not", "if", "then", "else",
    "contains", "additionalProperties", "unevaluatedProperties",
    "additionalItems", "unevaluatedItems", "contentSchema",
  ]

  /// Walks the schema tree and pre-compiles all `pattern` and `patternProperties`
  /// regex strings into `NSRegularExpression` objects.
  private static func compilePatterns(from schema: JSON) -> [String: LockedRegex] {
    var patterns: [String: LockedRegex] = [:]
    collectRegexPatterns(schema, patterns: &patterns)
    return patterns
  }

  // MARK: - Keyword cache

  /// Walks the schema tree and builds a dictionary mapping each subschema's
  /// JSON pointer to its keyword values (excluding `$ref` which is resolved).
  private static func buildKeywordCache(from schema: JSON) -> [String: [String: JSON]] {
    var cache: [String: [String: JSON]] = [:]
    buildKeywordCacheRecursive(schema, pointer: "", cache: &cache)
    return cache
  }

  /// Maximum recursion depth for `buildKeywordCacheRecursive`.
  /// Prevents stack overflow from deeply nested schemas.
  private static let keywordCacheMaxDepth = 100

  private static func buildKeywordCacheRecursive(
    _ value: JSON, pointer: String, cache: inout [String: [String: JSON]],
    depth: Int = 0
  ) {
    // Depth guard — prevent stack overflow from extremely nested schemas
    guard depth < keywordCacheMaxDepth else { return }
    guard value.isObject else { return }
    // Collect all keyword values from this subschema.
    var keywords: [String: JSON] = [:]
    if case .object(let dict) = value.storage {
      for (k, v) in dict {
        keywords[k] = v
      }
    }
    cache[pointer] = keywords
    // Recurse into properties (object properties) and items (array items).
    if let properties = value["properties"], properties.isObject {
      if case .object(let props) = properties.storage {
        for (key, sub) in props {
          let childPointer = pointer.isEmpty ? "/properties/" + key : pointer + "/properties/" + key
          buildKeywordCacheRecursive(sub, pointer: childPointer, cache: &cache, depth: depth + 1)
        }
      }
    }
    if let items = value["items"], items.isObject {
      // Single schema items
      buildKeywordCacheRecursive(
        items, pointer: pointer + "/items", cache: &cache, depth: depth + 1)
    } else if let itemsArr = value["items"], itemsArr.isArray {
      // Tuple array items
      for (i, item) in itemsArr.enumerated() {
        let childPointer = pointer + "/items/" + String(i)
        buildKeywordCacheRecursive(item, pointer: childPointer, cache: &cache, depth: depth + 1)
      }
    }
    // Recurse into $defs / definitions
    if let defs = value["$defs"], defs.isObject {
      if case .object(let defDict) = defs.storage {
        for (key, def) in defDict {
          let childPointer = pointer + "/$defs/" + key
          buildKeywordCacheRecursive(def, pointer: childPointer, cache: &cache, depth: depth + 1)
        }
      }
    }
    if let defs = value["definitions"], defs.isObject {
      if case .object(let defDict) = defs.storage {
        for (key, def) in defDict {
          let childPointer = pointer + "/definitions/" + key
          buildKeywordCacheRecursive(def, pointer: childPointer, cache: &cache, depth: depth + 1)
        }
      }
    }
    // Recurse into patternProperties (each value is a subschema)
    if let pp = value["patternProperties"], pp.isObject {
      if case .object(let patternDict) = pp.storage {
        for (pattern, sub) in patternDict {
          let childPointer = pointer + "/patternProperties/" + pattern
          buildKeywordCacheRecursive(sub, pointer: childPointer, cache: &cache, depth: depth + 1)
        }
      }
    }
    // Recurse into additionalProperties / unevaluatedProperties (if schema)
    if let ap = value["additionalProperties"], ap.isObject {
      buildKeywordCacheRecursive(
        ap, pointer: pointer + "/additionalProperties", cache: &cache, depth: depth + 1)
    }
    if let up = value["unevaluatedProperties"], up.isObject {
      buildKeywordCacheRecursive(
        up, pointer: pointer + "/unevaluatedProperties", cache: &cache, depth: depth + 1)
    }
    // Recurse into composition keywords (allOf, anyOf, oneOf, not, if, then, else)
    for comp in ["allOf", "anyOf", "oneOf"] {
      if let arr = value[comp], arr.isArray {
        for (i, sub) in arr.enumerated() {
          let childPointer = pointer + "/" + comp + "/" + String(i)
          buildKeywordCacheRecursive(sub, pointer: childPointer, cache: &cache, depth: depth + 1)
        }
      }
    }
    if let not = value["not"], not.isObject {
      buildKeywordCacheRecursive(not, pointer: pointer + "/not", cache: &cache, depth: depth + 1)
    }
    if let ifSub = value["if"], ifSub.isObject {
      buildKeywordCacheRecursive(ifSub, pointer: pointer + "/if", cache: &cache, depth: depth + 1)
    }
    if let thenSub = value["then"], thenSub.isObject {
      buildKeywordCacheRecursive(
        thenSub, pointer: pointer + "/then", cache: &cache, depth: depth + 1)
    }
    if let elseSub = value["else"], elseSub.isObject {
      buildKeywordCacheRecursive(
        elseSub, pointer: pointer + "/else", cache: &cache, depth: depth + 1)
    }
  }

  private static func collectRegexPatterns(_ value: JSON, patterns: inout [String: LockedRegex]) {
    guard value.isObject else { return }
    // Check for `pattern` keyword
    if let patternStr = value["pattern"]?.stringValue,
      patterns[patternStr] == nil,
      let regex = try? LockedRegex(pattern: patternStr)
    {
      patterns[patternStr] = regex
    }
    // Check for `patternProperties` keyword — it's an object whose keys are patterns
    if let pp = value["patternProperties"], pp.isObject {
      if case .object(let dict) = pp.storage {
        for (patternStr, _) in dict {
          if patterns[patternStr] == nil,
            let regex = try? LockedRegex(pattern: patternStr)
          {
            patterns[patternStr] = regex
          }
        }
      }
    }
    // Recurse into subschemas
    if let properties = value["properties"], properties.isObject {
      if case .object(let dict) = properties.storage {
        for (_, subschema) in dict {
          collectRegexPatterns(subschema, patterns: &patterns)
        }
      }
    }
    for keyword in Self.subschemaKeywords {
      if let subschema = value[keyword], subschema.isObject {
        collectRegexPatterns(subschema, patterns: &patterns)
      }
      if let arr = value[keyword], arr.isArray {
        for item in arr where item.isObject {
          collectRegexPatterns(item, patterns: &patterns)
        }
      }
    }
    if let defs = value["$defs"], defs.isObject {
      if case .object(let dict) = defs.storage {
        for (_, subschema) in dict {
          collectRegexPatterns(subschema, patterns: &patterns)
        }
      }
    }
    if let defs = value["definitions"], defs.isObject {
      if case .object(let dict) = defs.storage {
        for (_, subschema) in dict {
          collectRegexPatterns(subschema, patterns: &patterns)
        }
      }
    }
  }

  /// Returns the root resource scope (empty-string key).
  /// - Parameter resources: The resources dictionary.
  /// - Returns: The root `ResourceScope`.
  static func rootResource(_ resources: OrderedDictionary<String, ResourceScope>)
    -> ResourceScope?
  {
    return resources[""]
  }

  /// Collects per-resource annotations by walking the schema tree.
  private static func collectResources(from schema: JSON) throws -> OrderedDictionary<
    String, ResourceScope
  > {
    var resources = OrderedDictionary<String, ResourceScope>()
    try collectResourcesRecursive(schema, resources: &resources, currentBaseURI: "")
    return resources
  }

  /// Recursively walks a schema tree, grouping annotations by `$id`.
  private static func collectResourcesRecursive(
    _ schema: JSON,
    resources: inout OrderedDictionary<String, ResourceScope>,
    currentBaseURI: String
  ) throws {
    guard schema.isObject else { return }

    // Determine the base URI for this subschema by resolving the `$id`
    // value against the parent's base URI per RFC 3986.
    let childID = schema["$id"]?.stringValue
    let baseURI = resolveRelativeID(childID, parentBaseURI: currentBaseURI)

    // Ensure a resource scope exists for this base URI.
    // Duplicate $id is an authoring error per spec.
    if resources[baseURI] == nil {
      resources[baseURI] = ResourceScope(
        baseURI: baseURI,
        scopeSchema: schema,
        anchors: [:],
        dynamicAnchors: [:],
        defs: [:]
      )
    } else if schema["$id"]?.stringValue != nil {
      throw JSONSchemaError(
        instancePath: "",
        schemaPath: "/$id",
        keyword: "$id",
        message: "duplicate $id '\(baseURI)'"
      )
    }

    // Collect $defs at this level — only collect keys that don't already
    // exist in the resource's defs dictionary. Nested $defs entries with
    // the same key are NOT overwritten; the outermost occurrence wins.
    // Collect $defs (Draft 2020-12) or definitions (Draft 7) at this level.
    // Both keywords serve the same purpose; $defs is the modern form.
    if let defsJSON = schema["$defs"], defsJSON.isObject {
      if case .object(let defDict) = defsJSON.storage {
        for (key, value) in defDict {
          if resources[baseURI]?.defs[key] == nil {
            resources[baseURI]?.defs[key] = value
          }
          try collectResourcesRecursive(
            value, resources: &resources, currentBaseURI: baseURI
          )
        }
      }
    }
    if let defsJSON = schema["definitions"], defsJSON.isObject {
      if case .object(let defDict) = defsJSON.storage {
        for (key, value) in defDict {
          if resources[baseURI]?.defs[key] == nil {
            resources[baseURI]?.defs[key] = value
          }
          try collectResourcesRecursive(
            value, resources: &resources, currentBaseURI: baseURI
          )
        }
      }
    }

    // Collect $anchor at this level
    if let anchorStr = schema["$anchor"]?.stringValue {
      if resources[baseURI]?.anchors[anchorStr] != nil {
        throw JSONSchemaError(
          instancePath: "",
          schemaPath: "/$anchor",
          keyword: "$anchor",
          message: "duplicate $anchor '\(anchorStr)' in resource '\(baseURI)'"
        )
      }
      resources[baseURI]?.anchors[anchorStr] = schema
    }

    // Collect $dynamicAnchor at this level
    if let dynAnchorStr = schema["$dynamicAnchor"]?.stringValue {
      if resources[baseURI]?.dynamicAnchors[dynAnchorStr] != nil {
        throw JSONSchemaError(
          instancePath: "",
          schemaPath: "/$dynamicAnchor",
          keyword: "$dynamicAnchor",
          message: "duplicate $dynamicAnchor '\(dynAnchorStr)' in resource '\(baseURI)'"
        )
      }
      resources[baseURI]?.dynamicAnchors[dynAnchorStr] = schema
    }

    // Recurse into subschemas, passing the current resource's base URI
    // as the default for nested subschemas (unless they override with $id)

    // properties
    if let properties = schema["properties"], properties.isObject {
      if case .object(let dict) = properties.storage {
        for (_, propSchema) in dict {
          try collectResourcesRecursive(
            propSchema, resources: &resources, currentBaseURI: baseURI
          )
        }
      } else {
        preconditionFailure("properties.isObject true but storage not .object")
      }
    }

    // items / prefixItems
    if let items = schema["items"], items.isObject {
      try collectResourcesRecursive(
        items, resources: &resources, currentBaseURI: baseURI
      )
    }
    if let prefixItems = schema["prefixItems"], prefixItems.isArray {
      for item in prefixItems where item.isObject {
        try collectResourcesRecursive(
          item, resources: &resources, currentBaseURI: baseURI
        )
      }
    }

    // composition keywords
    for keyword in ["allOf", "anyOf", "oneOf"] {
      if let subschemas = schema[keyword], subschemas.isArray {
        for sub in subschemas where sub.isObject {
          try collectResourcesRecursive(
            sub, resources: &resources, currentBaseURI: baseURI
          )
        }
      }
    }
    if let notSchema = schema["not"], notSchema.isObject {
      try collectResourcesRecursive(
        notSchema, resources: &resources, currentBaseURI: baseURI
      )
    }
    if let ifSchema = schema["if"], ifSchema.isObject {
      try collectResourcesRecursive(
        ifSchema, resources: &resources, currentBaseURI: baseURI
      )
    }
    if let thenSchema = schema["then"], thenSchema.isObject {
      try collectResourcesRecursive(
        thenSchema, resources: &resources, currentBaseURI: baseURI
      )
    }
    if let elseSchema = schema["else"], elseSchema.isObject {
      try collectResourcesRecursive(
        elseSchema, resources: &resources, currentBaseURI: baseURI
      )
    }

    // patternProperties
    if let pp = schema["patternProperties"], pp.isObject {
      if case .object(let patternDict) = pp.storage {
        for (_, patternSchema) in patternDict {
          try collectResourcesRecursive(
            patternSchema, resources: &resources, currentBaseURI: baseURI
          )
        }
      } else {
        preconditionFailure("patternProperties.isObject true but storage not .object")
      }
    }

    // contains
    if let containsSchema = schema["contains"], containsSchema.isObject {
      try collectResourcesRecursive(
        containsSchema, resources: &resources, currentBaseURI: baseURI
      )
    }

    // additionalProperties / unevaluatedProperties
    if let ap = schema["additionalProperties"], ap.isObject {
      try collectResourcesRecursive(
        ap, resources: &resources, currentBaseURI: baseURI
      )
    }
    if let up = schema["unevaluatedProperties"], up.isObject {
      try collectResourcesRecursive(
        up, resources: &resources, currentBaseURI: baseURI
      )
    }

    // additionalItems / unevaluatedItems
    if let ai = schema["additionalItems"], ai.isObject {
      try collectResourcesRecursive(
        ai, resources: &resources, currentBaseURI: baseURI
      )
    }
    if let ui = schema["unevaluatedItems"], ui.isObject {
      try collectResourcesRecursive(
        ui, resources: &resources, currentBaseURI: baseURI
      )
    }

    // propertyNames
    if let pn = schema["propertyNames"], pn.isObject {
      try collectResourcesRecursive(
        pn, resources: &resources, currentBaseURI: baseURI
      )
    }

    // dependentSchemas
    if let depSchemas = schema["dependentSchemas"], depSchemas.isObject {
      if case .object(let depDict) = depSchemas.storage {
        for (_, depSchema) in depDict {
          try collectResourcesRecursive(
            depSchema, resources: &resources, currentBaseURI: baseURI
          )
        }
      } else {
        preconditionFailure("dependentSchemas.isObject true but storage not .object")
      }
    }
  }
}
