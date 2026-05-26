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
  }

  /// Resolves a `$ref` pointer against the schema and its `$defs`.
  ///
  /// - Parameter pointer: A JSON Pointer string (e.g., `#/$defs/foo`).
  /// - Returns: The resolved schema JSON, or `nil` if the pointer cannot be resolved.
  func resolveRef(_ pointer: String) -> JSON? {
    guard pointer.hasPrefix("#") else { return nil }

    // Build a JSON Pointer from the fragment (#/foo/bar → /foo/bar).
    // The JSONPointer struct handles RFC 6901 resolution including
    // escape sequences, array index validation, and leading-zero rejection.
    guard let ptr = try? JSONPointer(fragment: pointer) else { return nil }
    return ptr.resolve(schemaJSON)
  }
}
