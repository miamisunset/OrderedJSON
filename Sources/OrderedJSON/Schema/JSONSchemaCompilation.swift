import Foundation
import OrderedCollections

// MARK: - Resolved reference result

/// The result of resolving a `$ref` or `$dynamicRef` pointer.
/// Carries the resolved schema JSON along with the resource URI to use
/// for subsequent ref resolution within that schema.
struct ResolvedRef: Hashable {
  /// The resolved schema JSON (the target of the ref).
  let schema: JSON
  /// The resource URI to use for further ref resolution within `schema`.
  /// For remote schemas, this is the remote schema's URI.
  let resourceURI: String
}

// MARK: - Resource scope

/// Annotations scoped to a single base URI (established by `$id`).
struct ResourceScope: Hashable {
  /// The base URI for this resource (the `$id` value, or empty for root).
  var baseURI: String
  /// The schema JSON node where this resource was declared.
  /// Used as the root for JSON Pointer fallback in `resolveRef`.
  var scopeSchema: JSON
  /// Local anchors from `$anchor` keywords: anchor name → schema JSON.
  var anchors: OrderedDictionary<String, JSON>
  /// Dynamic anchors from `$dynamicAnchor` keywords: anchor name → schema JSON.
  var dynamicAnchors: OrderedDictionary<String, JSON>
  /// Resolved `$defs` entries: key → schema JSON.
  var defs: OrderedDictionary<String, JSON>
}

// MARK: - Compiled schema

// A compiled JSON Schema with per-resource (`$id`-scoped) annotation tables.
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
  let precompiledPatterns: [String: SendableRegex]
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
  private static func compilePatterns(from schema: JSON) -> [String: SendableRegex] {
    var patterns: [String: SendableRegex] = [:]
    collectPatterns(schema, patterns: &patterns)
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
  private static let maxKeywordCacheDepth = 100

  private static func buildKeywordCacheRecursive(
    _ value: JSON, pointer: String, cache: inout [String: [String: JSON]],
    depth: Int = 0
  ) {
    // Depth guard — prevent stack overflow from extremely nested schemas
    guard depth < maxKeywordCacheDepth else { return }
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

  private static func collectPatterns(_ value: JSON, patterns: inout [String: SendableRegex]) {
    guard value.isObject else { return }
    // Check for `pattern` keyword
    if let patternStr = value["pattern"]?.stringValue,
      patterns[patternStr] == nil,
      let regex = try? SendableRegex(pattern: patternStr)
    {
      patterns[patternStr] = regex
    }
    // Check for `patternProperties` keyword — it's an object whose keys are patterns
    if let pp = value["patternProperties"], pp.isObject {
      if case .object(let dict) = pp.storage {
        for (patternStr, _) in dict {
          if patterns[patternStr] == nil,
            let regex = try? SendableRegex(pattern: patternStr)
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
          collectPatterns(subschema, patterns: &patterns)
        }
      }
    }
    for keyword in Self.subschemaKeywords {
      if let subschema = value[keyword], subschema.isObject {
        collectPatterns(subschema, patterns: &patterns)
      }
      if let arr = value[keyword], arr.isArray {
        for item in arr where item.isObject {
          collectPatterns(item, patterns: &patterns)
        }
      }
    }
    if let defs = value["$defs"], defs.isObject {
      if case .object(let dict) = defs.storage {
        for (_, subschema) in dict {
          collectPatterns(subschema, patterns: &patterns)
        }
      }
    }
    if let defs = value["definitions"], defs.isObject {
      if case .object(let dict) = defs.storage {
        for (_, subschema) in dict {
          collectPatterns(subschema, patterns: &patterns)
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

  // MARK: - RFC 3986 URI joining

  /// Resolves a relative `$id` value against a parent base URI per RFC 3986.
  ///
  /// Uses Foundation's `URL` type which handles the common cases:
  /// - Absolute URIs (with scheme): returned as-is
  /// - Network-path URIs (starting with `//`): authority replaced
  /// - Absolute path URIs (starting with `/`): path+query replaced
  /// - Relative path URIs: merged with parent's path
  /// - Fragment-only URIs (`#foo`): parent URI with fragment replaced
  /// - Empty `$id` (or missing `$id`): parent URI returned unchanged
  ///
  /// - Parameters:
  ///   - child: The `$id` value from the subschema (may be empty/absent).
  ///   - parent: The parent resource's base URI (empty for root).
  /// - Returns: The resolved absolute URI string.
  static func resolveRelativeID(_ child: String?, parent: String) -> String {
    guard let child = child, !child.isEmpty else { return parent }

    // Absolute URI — use as-is
    if let url = URL(string: child), url.scheme != nil {
      return child
    }

    // Parent is empty (root with no $id) — use child as-is
    if parent.isEmpty {
      return child
    }

    // Resolve relative URI against parent base
    guard let base = URL(string: parent) else { return child }
    guard let resolved = URL(string: child, relativeTo: base)?.absoluteString else { return child }
    return resolved
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
    let baseURI = resolveRelativeID(childID, parent: currentBaseURI)

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

  /// Resolves a `$ref` pointer against the schema's resources.
  ///
  /// Supports:
  /// - `#` → root schema
  /// - `#anchorName` → anchor in the current resource
  /// - `#/$defs/key` → `$defs` entry in the current resource
  /// - `#/$defs/key/tail` → deep pointer into a `$defs` entry
  /// - `#/foo/bar` → JSON Pointer into the current resource's schema
  /// - `resourceURI#` or `resourceURI#/path` → external resource
  ///
  /// External references without a `#` fragment currently return `nil`.
  ///
  /// - Parameters:
  ///   - pointer: A `$ref` pointer string (may include URI).
  ///   - currentResourceURI: The base URI of the resource from which this
  ///     `$ref` is being resolved. Local `#…` refs resolve against this
  ///     resource's annotation tables, not the root.
  /// - Returns: The resolved schema JSON, or `nil` if unresolvable.
  func resolveRef(
    _ pointer: String, currentResourceURI: String = "",
    remoteRegistry: [String: CompiledSchema]? = nil
  ) -> ResolvedRef? {
    // Split on '#' to separate URI from fragment.
    let parts = pointer.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)

    let uriPart: String
    let fragmentPart: String

    if parts.count == 2 {
      uriPart = String(parts[0])
      fragmentPart = String(parts[1])
    } else if parts.count == 1 {
      uriPart = String(parts[0])
      fragmentPart = ""
    } else {
      preconditionFailure("unexpected parts count from split")
    }

    // Helper: check if fragment matches a resource key (e.g., $id: "#foo")
    func resolveFragmentByResource(
      _ fragment: String, in resources: OrderedDictionary<String, ResourceScope>,
      currentURI: String
    ) -> ResolvedRef? {
      guard !fragment.hasPrefix("/") else { return nil }
      let key1 =
        currentURI.isEmpty || currentURI.hasSuffix("#")
        ? fragment
        : currentURI + "#" + fragment
      let key2 = "#" + fragment
      if let matched = resources[key1] ?? resources[key2] ?? resources[fragment] {
        return ResolvedRef(schema: matched.scopeSchema, resourceURI: matched.baseURI)
      }
      return nil
    }

    // Determine which resource scope to use.
    if uriPart.isEmpty {
      // Local ref — resolve fragment within the current resource.
      // First check local resources, then remote registry if currentResourceURI
      // refers to a remote schema (e.g., after resolving a remote ref).
      if let resource = resources[currentResourceURI] {
        // For non-pointer fragments, also check if fragment matches a
        // resource key (e.g., $id: "#detached" creates resource "<uri>#detached")
        if let matched = resolveFragmentByResource(
          fragmentPart, in: resources,
          currentURI: currentResourceURI
        ) {
          return matched
        }
        var fragURI = currentResourceURI
        guard let schema = resolveFragment(fragmentPart, in: resource, resourceURI: &fragURI) else {
          return nil
        }
        return ResolvedRef(schema: schema, resourceURI: fragURI)
      }
      if let remoteCompiled = remoteRegistry?[currentResourceURI] {
        var fragURI = currentResourceURI
        guard
          let schema = resolveFragment(
            fragmentPart, in: remoteCompiled,
            resourceURI: &fragURI
          )
        else { return nil }
        return ResolvedRef(schema: schema, resourceURI: fragURI)
      }
      return nil
    }

    // Resolve the URI part relative to currentResourceURI
    let resolvedURI = CompiledSchema.resolveRelativeID(uriPart, parent: currentResourceURI)

    // Check local resources first
    if let resource = resources[resolvedURI] {
      // For non-pointer fragments, check if fragment matches a resource key
      if !fragmentPart.isEmpty, !fragmentPart.hasPrefix("/") {
        if let matched = resolveFragmentByResource(
          fragmentPart, in: resources,
          currentURI: resolvedURI
        ) {
          return matched
        }
      }
      var fragURI = resolvedURI
      guard let schema = resolveFragment(fragmentPart, in: resource, resourceURI: &fragURI) else {
        return nil
      }
      return ResolvedRef(schema: schema, resourceURI: fragURI)
    }

    // Check remote registry as fallback
    if let remoteCompiled = remoteRegistry?[resolvedURI] {
      var fragURI = resolvedURI
      guard let schema = resolveFragment(fragmentPart, in: remoteCompiled, resourceURI: &fragURI)
      else { return nil }
      return ResolvedRef(schema: schema, resourceURI: fragURI)
    }

    return nil
  }

  // MARK: - Fragment resolution

  /// Resolves a `#fragment` within a `ResourceScope`.
  /// Handles empty fragment (root), anchor names, `/$defs/…`, and JSON Pointers.
  private func resolveFragment(
    _ fragment: String, in resource: ResourceScope, resourceURI: inout String
  ) -> JSON? {
    if fragment.isEmpty { return resource.scopeSchema }
    // URI percent-decode the fragment before applying JSON Pointer unescaping.
    let decoded = fragment.removingPercentEncoding ?? fragment
    if !decoded.hasPrefix("/") {
      return resource.anchors[decoded] ?? resource.dynamicAnchors[decoded]
    }
    if decoded.hasPrefix("/$defs/") || decoded.hasPrefix("/definitions/") {
      let prefix = decoded.hasPrefix("/$defs/") ? "/$defs/" : "/definitions/"
      let rest = String(decoded.dropFirst(prefix.count))
      if let slashIndex = rest.firstIndex(of: "/") {
        let headRaw = String(rest[rest.startIndex..<slashIndex])
        let head = unescapeJSONPointerSegment(headRaw)
        let tail = String(rest[slashIndex...])
        if let target = resource.defs[head] {
          // Check if the target definition has $id and update resourceURI
          if let childID = target["$id"]?.stringValue {
            resourceURI = CompiledSchema.resolveRelativeID(childID, parent: resourceURI)
          }
          guard let ptr = try? JSONPointer(tail) else { return nil }
          return ptr.resolve(target)
        }
      } else {
        let key = unescapeJSONPointerSegment(rest)
        if let target = resource.defs[key] {
          // Check if the target definition has $id and update resourceURI
          if let childID = target["$id"]?.stringValue {
            resourceURI = CompiledSchema.resolveRelativeID(childID, parent: resourceURI)
          }
          return target
        }
      }
    }
    // decoded is already percent-decoded — use path init (not fragment init)
    // to avoid double percent-decoding which would corrupt literal % chars.
    guard let ptr = try? JSONPointer(decoded) else { return nil }
    return ptr.resolve(resource.scopeSchema)
  }

  /// Resolves a `#fragment` within a `CompiledSchema`.
  /// Uses the resource matching `resourceURI` (or the first available resource).
  /// When fragment is empty, returns that resource's scope schema.
  private func resolveFragment(
    _ fragment: String, in compiled: CompiledSchema,
    resourceURI: inout String
  ) -> JSON? {
    // For empty fragment, directly use the resource matching resourceURI
    // (or first available resource) without checking fragment-based keys.
    if fragment.isEmpty {
      guard
        let resource = compiled.resources[resourceURI]
          ?? compiled.resources[""]
          ?? compiled.resources.values.first
      else { return nil }
      if !resource.baseURI.isEmpty {
        resourceURI = resource.baseURI
      }
      return resource.scopeSchema
    }
    // If the fragment matches a resource key (e.g., $id: "#detached" creates
    // a resource with URI "<parent>#detached"), return that resource's schema.
    if !fragment.hasPrefix("/") {
      // Fragment is an anchor name or $id fragment — check resources first
      // Try multiple resource key forms (see resolveRef for details)
      let key1 =
        resourceURI.hasSuffix("#") || resourceURI.isEmpty
        ? fragment
        : resourceURI + "#" + fragment
      let key2 = "#" + fragment
      if let matched = compiled.resources[key1] ?? compiled.resources[key2]
        ?? compiled.resources[fragment]
      {
        // Keep the original resourceURI if the matched resource has no $id
        if !matched.baseURI.isEmpty {
          resourceURI = matched.baseURI
        }
        return matched.scopeSchema
      }
    }
    // Try exact match, then empty-string root, then fall back to first resource.
    guard
      let resource = compiled.resources[resourceURI]
        ?? compiled.resources[""]
        ?? compiled.resources.values.first
    else { return nil }
    return resolveFragment(fragment, in: resource, resourceURI: &resourceURI)
  }

  /// Resolves a `$dynamicRef` pointer against the dynamic scope.
  ///
  /// Per Draft 2020-12, `$dynamicRef` with a fragment like `#myAnchor`
  /// resolves against the nearest `$dynamicAnchor` with that name in the
  /// validation chain. If no dynamic anchor is found, falls back to normal
  /// `$ref` resolution against the current resource's anchors.
  ///
  /// - Parameters:
  ///   - pointer: The `$dynamicRef` pointer string.
  ///   - dynamicScope: The current stack of dynamic anchor frames (name, schema),
  ///     innermost first.
  ///   - currentResourceURI: The base URI of the resource from which this
  ///     `$dynamicRef` is being resolved.
  ///   - remoteRegistry: Optional dictionary of remote compiled schemas
  ///     keyed by URL, consulted when local resolution fails.
  /// - Returns: The resolved schema JSON, or `nil` if unresolvable.
  func resolveDynamicRef(
    _ pointer: String,
    dynamicScope: [DynamicAnchorFrame],
    currentResourceURI: String = "",
    remoteRegistry: [String: CompiledSchema]? = nil
  ) -> ResolvedRef? {
    // Per spec, $dynamicRef resolves in two steps:
    // 1. Resolve as normal $ref to get the initial target
    // 2. If the fragment matches a $dynamicAnchor, replace with the
    //    outermost schema resource in the dynamic scope that defines
    //    an identically named $dynamicAnchor
    //
    // If the fragment does NOT match a $dynamicAnchor, behave exactly
    // like normal $ref.

    // Step 1: resolve as normal $ref
    guard
      let initialRef = resolveRef(
        pointer, currentResourceURI: currentResourceURI, remoteRegistry: remoteRegistry
      )
    else { return nil }

    // Check if the resolved schema has a $dynamicAnchor that matches
    // the fragment used in the $dynamicRef.
    let fragment: String
    if let hashIndex = pointer.firstIndex(of: "#") {
      fragment = String(pointer[hashIndex...].dropFirst())
    } else {
      fragment = ""
    }

    let isDynamicAnchor: Bool
    if let dynAnchor = initialRef.schema["$dynamicAnchor"]?.stringValue {
      isDynamicAnchor = (dynAnchor == fragment)
    } else {
      isDynamicAnchor = false
    }

    if isDynamicAnchor {
      // Step 2: find the outermost $dynamicAnchor with this name in the
      // dynamic scope. The dynamic scope is populated in push order
      // (outermost first = earliest pushed).
      for frame in dynamicScope {
        if frame.name == fragment {
          return ResolvedRef(schema: frame.schema, resourceURI: currentResourceURI)
        }
      }
      // Fall back to the initial $ref result (no outer anchor found)
      return initialRef
    } else {
      // Fragment doesn't match a $dynamicAnchor — behave like normal $ref
      return initialRef
    }
  }
}
