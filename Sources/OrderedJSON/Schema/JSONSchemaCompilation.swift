import Foundation
import OrderedCollections

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

    // Determine the base URI for this subschema
    let baseURI: String
    if let id = schema["$id"]?.stringValue {
      baseURI = id
    } else {
      baseURI = currentBaseURI
    }

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

    // Collect $defs at this level
    if let defsJSON = schema["$defs"], defsJSON.isObject {
      if case .object(let defDict) = defsJSON.storage {
        for (key, value) in defDict {
          resources[baseURI]?.defs[key] = value
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
  func resolveRef(_ pointer: String, currentResourceURI: String = "") -> JSON? {
    // Split on '#' to separate URI from fragment.
    // TODO: bare URIs without # (e.g., "foo.json") are external-resource refs
    // that should resolve to the resource root. Currently returns nil.
    let parts = pointer.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2 else { return nil }

    let uriPart = String(parts[0])
    let fragmentPart = String(parts[1])

    // Determine which resource scope to use
    let resourceBaseURI: String
    if uriPart.isEmpty {
      // Local reference — use the current resource scope
      resourceBaseURI = currentResourceURI
    } else {
      // External reference — try to find matching resource
      guard resources[uriPart] != nil else { return nil }
      resourceBaseURI = uriPart
    }

    guard let resource = resources[resourceBaseURI] else { return nil }

    // Root reference # with no fragment — root of the resource
    if fragmentPart.isEmpty {
      return resource.scopeSchema
    }

    // Check for $anchor references: #anchorName (no slash after #)
    if !fragmentPart.hasPrefix("/") {
      let anchorName = fragmentPart
      return resource.anchors[anchorName]
    }

    // Check for #/$defs/<key> or #/$defs/<key>/<tail>
    if fragmentPart.hasPrefix("/$defs/") {
      let rest = String(fragmentPart.dropFirst("/$defs/".count))
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
        if let target = resource.defs[key] {
          return target
        }
      }
    }

    // Build a JSON Pointer from the fragment (e.g., #/foo/bar → /foo/bar).
    // The fragment always has a leading / at this point (anchor-name case
    // returned above), so we prepend # to form a fragment identifier.
    // Resolve against the resource's scope schema, not the root schemaJSON.
    guard let ptr = try? JSONPointer(fragment: "#" + fragmentPart) else { return nil }
    return ptr.resolve(resource.scopeSchema)
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
  ///   - dynamicScope: The current stack of dynamic anchor tuples (name, schema),
  ///     innermost first.
  ///   - currentResourceURI: The base URI of the resource from which this
  ///     `$dynamicRef` is being resolved.
  /// - Returns: The resolved schema JSON, or `nil` if unresolvable.
  func resolveDynamicRef(
    _ pointer: String,
    dynamicScope: [(String, JSON)],
    currentResourceURI: String = ""
  ) -> JSON? {
    guard pointer.hasPrefix("#") else { return nil }

    // Extract the anchor name (the fragment after #).
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

    // Fall back to the current resource's dynamic anchors
    if let resource = resources[currentResourceURI],
      let target = resource.dynamicAnchors[anchorName]
    {
      return target
    }

    // Final fallback: treat as normal $ref (static anchor from current resource)
    if let resource = resources[currentResourceURI],
      let target = resource.anchors[anchorName]
    {
      return target
    }

    return nil
  }
}
