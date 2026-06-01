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
///
/// Each `$id` keyword establishes a new resource scope. The scope collects
/// anchors, dynamic anchors, and `$defs` entries for that URI. The root
/// resource (no `$id`) uses an empty-string key.
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

// MARK: - Ref resolution

extension CompiledSchema {

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
  ///   - remoteRegistry: Optional dictionary of remote compiled schemas
  ///     keyed by URL, consulted when local resolution fails.
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
    let resolvedURI = CompiledSchema.resolveRelativeID(uriPart, parentBaseURI: currentResourceURI)

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
  func resolveFragment(
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
          if let childID = target[key: .dollarId]?.stringValue {
            resourceURI = CompiledSchema.resolveRelativeID(childID, parentBaseURI: resourceURI)
          }
          guard let ptr = try? JSONPointer(tail) else { return nil }
          return ptr.resolve(target)
        }
      } else {
        let key = unescapeJSONPointerSegment(rest)
        if let target = resource.defs[key] {
          // Check if the target definition has $id and update resourceURI
          if let childID = target[key: .dollarId]?.stringValue {
            resourceURI = CompiledSchema.resolveRelativeID(childID, parentBaseURI: resourceURI)
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
  func resolveFragment(
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
    if let dynAnchor = initialRef.schema[key: .dollarDynamicAnchor]?.stringValue {
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
