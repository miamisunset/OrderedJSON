import Foundation
import OrderedCollections

// MARK: - Resolved reference result

/// The result of resolving a `$ref` or `$dynamicRef` pointer.
/// Carries the resolved schema JSON along with the resource URI to use
/// for subsequent ref resolution within that schema.
internal struct ResolvedRef: Hashable, Sendable {
  /// The resolved schema JSON (the target of the ref).
  let schema: JSON
  /// The resource URI to use for further ref resolution within `schema`.
  /// For remote schemas, this is the remote schema's URI.
  let resourceURI: String
}

// MARK: - Resource scope

/// Annotations scoped to a single base URI (established by `$id`).
internal struct ResourceScope: Hashable, Sendable {
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

/// A compiled JSON Schema with per-resource (`$id`-scoped) annotation tables.
///
/// Compilation walks the raw schema JSON once at init time:
/// - Identifies embedded resources via `$id` keywords
/// - Collects `$defs`, `$anchor`, `$dynamicAnchor` per resource
/// - The root resource (no `$id`) uses an empty-string key
///
/// ### Relative `$id` resolution
///
/// Per Draft 2020-12 / RFC 3986, a nested `$id` value is resolved against
/// its parent resource's base URI to form an absolute URI. For example:
///
/// ```json
/// {
///   "$id": "https://example.com/root",
///   "properties": {
///     "child": { "$id": "child", ... }
///   }
/// }
/// ```
///
/// The child resource's base URI becomes `https://example.com/child`.
/// A subsequent `$ref: "https://example.com/child#"` will match.
internal struct CompiledSchema: Hashable, Sendable {
  /// The raw schema JSON (kept for un-compiled keyword access).
  let schemaJSON: JSON
  /// Per-resource annotation tables, keyed by base URI (empty string for root).
  let resources: OrderedDictionary<String, ResourceScope>

  /// Creates a compiled schema from raw JSON.
  /// - Parameter schema: The raw schema JSON.
  /// - Throws: `JSONSchemaError` if duplicate anchors are found.
  init(schema: JSON) throws {
    self.schemaJSON = schema
    self.resources = try CompiledSchema.collectResources(from: schema)
  }

  /// Returns the root resource scope (empty-string key).
  /// - Parameter resources: The resources dictionary.
  /// - Returns: The root `ResourceScope`.
  internal static func rootResource(_ resources: OrderedDictionary<String, ResourceScope>)
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
  internal static func resolveRelativeID(_ child: String?, parent: String) -> String {
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
    if let defsJSON = schema["$defs"], defsJSON.isObject {
      if case .object(let defDict) = defsJSON.storage {
        for (key, value) in defDict {
          if resources[baseURI]?.defs[key] == nil {
            resources[baseURI]?.defs[key] = value
          }
          try collectResourcesRecursive(
            value, resources: &resources, currentBaseURI: baseURI)
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
            propSchema, resources: &resources, currentBaseURI: baseURI)
        }
      } else {
        preconditionFailure("properties.isObject true but storage not .object")
      }
    }

    // items / prefixItems
    if let items = schema["items"], items.isObject {
      try collectResourcesRecursive(
        items, resources: &resources, currentBaseURI: baseURI)
    }
    if let prefixItems = schema["prefixItems"], prefixItems.isArray {
      for item in prefixItems where item.isObject {
        try collectResourcesRecursive(
          item, resources: &resources, currentBaseURI: baseURI)
      }
    }

    // composition keywords
    for keyword in ["allOf", "anyOf", "oneOf"] {
      if let subschemas = schema[keyword], subschemas.isArray {
        for sub in subschemas where sub.isObject {
          try collectResourcesRecursive(
            sub, resources: &resources, currentBaseURI: baseURI)
        }
      }
    }
    if let notSchema = schema["not"], notSchema.isObject {
      try collectResourcesRecursive(
        notSchema, resources: &resources, currentBaseURI: baseURI)
    }
    if let ifSchema = schema["if"], ifSchema.isObject {
      try collectResourcesRecursive(
        ifSchema, resources: &resources, currentBaseURI: baseURI)
    }
    if let thenSchema = schema["then"], thenSchema.isObject {
      try collectResourcesRecursive(
        thenSchema, resources: &resources, currentBaseURI: baseURI)
    }
    if let elseSchema = schema["else"], elseSchema.isObject {
      try collectResourcesRecursive(
        elseSchema, resources: &resources, currentBaseURI: baseURI)
    }

    // patternProperties
    if let pp = schema["patternProperties"], pp.isObject {
      if case .object(let patternDict) = pp.storage {
        for (_, patternSchema) in patternDict {
          try collectResourcesRecursive(
            patternSchema, resources: &resources, currentBaseURI: baseURI)
        }
      } else {
        preconditionFailure("patternProperties.isObject true but storage not .object")
      }
    }

    // contains
    if let containsSchema = schema["contains"], containsSchema.isObject {
      try collectResourcesRecursive(
        containsSchema, resources: &resources, currentBaseURI: baseURI)
    }

    // additionalProperties / unevaluatedProperties
    if let ap = schema["additionalProperties"], ap.isObject {
      try collectResourcesRecursive(
        ap, resources: &resources, currentBaseURI: baseURI)
    }
    if let up = schema["unevaluatedProperties"], up.isObject {
      try collectResourcesRecursive(
        up, resources: &resources, currentBaseURI: baseURI)
    }

    // additionalItems / unevaluatedItems
    if let ai = schema["additionalItems"], ai.isObject {
      try collectResourcesRecursive(
        ai, resources: &resources, currentBaseURI: baseURI)
    }
    if let ui = schema["unevaluatedItems"], ui.isObject {
      try collectResourcesRecursive(
        ui, resources: &resources, currentBaseURI: baseURI)
    }

    // propertyNames
    if let pn = schema["propertyNames"], pn.isObject {
      try collectResourcesRecursive(
        pn, resources: &resources, currentBaseURI: baseURI)
    }

    // dependentSchemas
    if let depSchemas = schema["dependentSchemas"], depSchemas.isObject {
      if case .object(let depDict) = depSchemas.storage {
        for (_, depSchema) in depDict {
          try collectResourcesRecursive(
            depSchema, resources: &resources, currentBaseURI: baseURI)
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
  func resolveRef(_ pointer: String, currentResourceURI: String = "",
    remoteRegistry: [String: CompiledSchema]? = nil) -> ResolvedRef? {
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

    // Determine which resource scope to use.
    if uriPart.isEmpty {
      // Local ref — resolve fragment within the current resource.
      // First check local resources, then remote registry if currentResourceURI
      // refers to a remote schema (e.g., after resolving a remote ref).
      if let resource = resources[currentResourceURI] {
        guard let schema = resolveFragment(fragmentPart, in: resource) else { return nil }
        return ResolvedRef(schema: schema, resourceURI: currentResourceURI)
      }
      if let remoteCompiled = remoteRegistry?[currentResourceURI] {
        guard let schema = resolveFragment(fragmentPart, in: remoteCompiled,
          resourceURI: currentResourceURI) else { return nil }
        return ResolvedRef(schema: schema, resourceURI: currentResourceURI)
      }
      return nil
    }

    // Resolve the URI part relative to currentResourceURI
    let resolvedURI = CompiledSchema.resolveRelativeID(uriPart, parent: currentResourceURI)

    // Check local resources first
    if let resource = resources[resolvedURI] {
      guard let schema = resolveFragment(fragmentPart, in: resource) else { return nil }
      return ResolvedRef(schema: schema, resourceURI: resolvedURI)
    }

    // Check remote registry as fallback
    if let remoteCompiled = remoteRegistry?[resolvedURI] {
      guard let schema = resolveFragment(fragmentPart, in: remoteCompiled, resourceURI: resolvedURI) else { return nil }
      return ResolvedRef(schema: schema, resourceURI: resolvedURI)
    }

    return nil
  }

  // MARK: - Fragment resolution

  /// Resolves a `#fragment` within a `ResourceScope`.
  /// Handles empty fragment (root), anchor names, `/$defs/…`, and JSON Pointers.
  private func resolveFragment(_ fragment: String, in resource: ResourceScope) -> JSON? {
    if fragment.isEmpty { return resource.scopeSchema }
    // URI percent-decode the fragment before applying JSON Pointer unescaping.
    let decoded = fragment.removingPercentEncoding ?? fragment
    if !decoded.hasPrefix("/") { return resource.anchors[decoded] ?? resource.dynamicAnchors[decoded] }
    if decoded.hasPrefix("/$defs/") {
      let rest = String(decoded.dropFirst("/$defs/".count))
      if let slashIndex = rest.firstIndex(of: "/") {
        let headRaw = String(rest[rest.startIndex..<slashIndex])
        let head = unescapeJSONPointerSegment(headRaw)
        let tail = String(rest[slashIndex...])
        if let target = resource.defs[head] {
          guard let ptr = try? JSONPointer(tail) else { return nil }
          return ptr.resolve(target)
        }
      } else {
        let key = unescapeJSONPointerSegment(rest)
        return resource.defs[key]
      }
    }
    guard let ptr = try? JSONPointer(fragment: "#" + decoded) else { return nil }
    return ptr.resolve(resource.scopeSchema)
  }

  /// Resolves a `#fragment` within a `CompiledSchema`.
  /// Uses the resource matching `resourceURI` (or the first available resource).
  /// When fragment is empty, returns that resource's scope schema.
  private func resolveFragment(_ fragment: String, in compiled: CompiledSchema,
    resourceURI: String = "") -> JSON? {
    // Try exact match, then empty-string root, then fall back to first resource.
    guard let resource = compiled.resources[resourceURI]
      ?? compiled.resources[""]
      ?? compiled.resources.first(where: { _ in true })?.value
      else { return nil }
    if fragment.isEmpty {
      return resource.scopeSchema
    }
    return resolveFragment(fragment, in: resource)
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
    guard let initialRef = resolveRef(
      pointer, currentResourceURI: currentResourceURI, remoteRegistry: remoteRegistry)
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
