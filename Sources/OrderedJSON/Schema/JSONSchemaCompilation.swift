import Foundation
import OrderedCollections

// MARK: - Compiled schema keyword

/// A pre-parsed keyword node in a compiled schema tree.
///
/// Instead of re-parsing the schema JSON on every validation call, the
/// compiler walks the schema once at init time and produces a tree of
/// `CompiledKeyword` nodes. Each node stores its parsed parameters and
/// resolved `$ref` targets.
internal enum CompiledKeyword: Hashable, Sendable {
  /// A keyword with a simple JSON value (e.g., `type: "string"`).
  case keyword(key: String, value: JSON)
  /// A subschema keyword (e.g., `items`, `contains`, `propertyNames`).
  case subschema(key: String, schema: JSON)
  /// A list of subschemas (e.g., `prefixItems`, `allOf`).
  case subschemas(key: String, schemas: [JSON])
  /// A `$ref` that resolves to a target schema.
  case `ref`(pointer: String, target: JSON?)
  /// A `$defs` entry.
  case def(key: String, schema: JSON)
}

// MARK: - Compiled schema

/// A compiled JSON Schema with pre-resolved `$ref`, `$defs`, `$id`, and `$anchor`.
///
/// Compilation walks the raw schema JSON once at init time:
/// - Extracts `$defs` entries into a lookup dictionary
/// - Resolves `$ref` pointers by following the JSON Pointer into the schema
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
  /// - Throws: If `$defs` entries are malformed.
  init(schema: JSON) throws {
    self.schemaJSON = schema

    // Parse $defs
    if let defsJSON = schema["$defs"], defsJSON.isObject {
      guard case .object(let defDict) = defsJSON.storage else {
        throw JSONSchemaError(
          instancePath: "", schemaPath: "",
          keyword: "$defs",
          message: "$defs must be an object")
      }
      self.defs = defDict
    } else {
      self.defs = [:]
    }

    // Parse $id
    if let idStr = schema["$id"]?.stringValue {
      self.baseURI = idStr
    } else {
      self.baseURI = nil
    }

    // Parse $anchor
    if let anchorStr = schema["$anchor"]?.stringValue {
      self.anchors = [anchorStr: schema]
    } else {
      self.anchors = [:]
    }
  }

  /// Resolves a `$ref` pointer against the schema and its `$defs`.
  ///
  /// - Parameter pointer: A JSON Pointer string (e.g., `#/$defs/foo`).
  /// - Returns: The resolved schema JSON, or `nil` if the pointer cannot be resolved.
  func resolveRef(_ pointer: String) -> JSON? {
    // Local references start with #
    guard pointer.hasPrefix("#") else { return nil }

    let fragment: String
    if pointer == "#" {
      fragment = ""
    } else {
      fragment = String(pointer.dropFirst())
    }

    // Handle $defs references: #/$defs/name
    if fragment.hasPrefix("/$defs/") {
      let defKey = String(fragment.dropFirst("/$defs/".count))
      return defs[defKey]
    }

    // Resolve JSON Pointer against the schema itself
    if fragment.isEmpty {
      return schemaJSON
    }
    return schemaJSON.resolve(fragment)
  }
}

// MARK: - JSON Pointer resolution

extension JSON {
  /// Resolves a JSON Pointer (RFC 6901) against this JSON value.
  ///
  /// - Parameter pointer: A JSON Pointer string starting with `/`.
  /// - Returns: The value at the pointer, or `nil` if the path doesn't exist.
  internal func resolve(_ pointer: String) -> JSON? {
    guard pointer.hasPrefix("/") else { return nil }

    let segments = pointer.dropFirst().split(separator: "/", omittingEmptySubstrings: false)
    var current: JSON = self

    for segment in segments {
      let decoded = decodePointerSegment(String(segment))
      if let index = Int(decoded), current.isArray, let arr = current.arrayValue {
        guard index >= 0, index < arr.count else { return nil }
        current = arr[index]
      } else if current.isObject {
        guard let next = current[decoded] else { return nil }
        current = next
      } else {
        return nil
      }
    }

    return current
  }

  /// Decodes a single JSON Pointer segment, replacing `~0` (tilde → `~`)
  /// and `~1` (forward slash → `/`).
  private static func decodePointerSegment(_ segment: String) -> String {
    var decoded = segment
      .replacingOccurrences(of: "~1", with: "/")
      .replacingOccurrences(of: "~0", with: "~")
    return decoded
  }
}
