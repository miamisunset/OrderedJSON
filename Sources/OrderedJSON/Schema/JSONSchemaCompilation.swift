import Foundation
import OrderedCollections

// MARK: - Compiled schema

/// A compiled JSON Schema with pre-resolved `$defs`, `$id`, and `$anchor`.
///
/// Compilation walks the raw schema JSON once at init time:
/// - Extracts `$defs` entries into a lookup dictionary
/// - Parses `$id` for base URI resolution
/// - Parses `$anchor` for local anchor lookup
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

    // Parse $defs
    if let defsJSON = schema["$defs"], defsJSON.isObject {
      guard case .object(let defDict) = defsJSON.storage else {
        defs = [:]
        baseURI = nil
        anchors = [:]
        dynamicAnchors = [:]
        return
      }
      defs = defDict
    } else {
      defs = [:]
    }

    // Parse $id
    baseURI = schema["$id"]?.stringValue

    // Parse $anchor
    if let anchorStr = schema["$anchor"]?.stringValue {
      anchors = [anchorStr: schema]
    } else {
      anchors = [:]
    }

    // Parse $dynamicAnchor
    if let dynAnchorStr = schema["$dynamicAnchor"]?.stringValue {
      dynamicAnchors = [dynAnchorStr: schema]
    } else {
      dynamicAnchors = [:]
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
