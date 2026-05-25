import Foundation
import OrderedCollections

/// Errors specific to flatten/unflatten operations.
public enum FlattenError: Error, Hashable, Sendable, CustomStringConvertible {
  /// The input to unflatten() is not a JSON object.
  case notObject
  /// A value in the flattened object is not a primitive type.
  case notPrimitive(String)

  public var description: String {
    switch self {
    case .notObject:
      return "only objects can be unflattened"
    case .notPrimitive(let key):
      return "values in object must be primitive; key '\(key)' has a non-primitive value"
    }
  }
}

extension JSON {
  /// Flattens nested JSON into a flat object with JSON Pointer keys (`/a/b/c`).
  ///
  /// Each leaf value is mapped to a JSON Pointer path. Empty objects and
  /// arrays are flattened to `null`. Non-object roots are returned as an
  /// object with a single `""` key.
  ///
  /// - Returns: A `JSON` object where each key is a JSON Pointer path and
  ///   each value is a leaf value.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let json = JSON.object([
  ///   "a": .object(["b": .number(.integer(1)), "c": .number(.integer(2))])
  /// ])
  /// let flat = json.flatten()
  /// // flat["/a/b"] == 1
  /// // flat["/a/c"] == 2
  /// ```
  public func flatten() -> JSON {
    var result = OrderedDictionary<String, JSON>()
    flattenInternal(prefix: "", into: &result)
    return .object(result)
  }

  private func flattenInternal(prefix: String, into result: inout OrderedDictionary<String, JSON>) {
    switch storage {
    case .null, .boolean, .number, .string:
      result[prefix] = self
    case .array(let elements):
      guard !elements.isEmpty else {
        // RFC 6901 §4: empty arrays are flattened to null
        result[prefix] = JSON.null
        return
      }
      for (index, element) in elements.enumerated() {
        let key = prefix.isEmpty ? "/\(index)" : "\(prefix)/\(index)"
        element.flattenInternal(prefix: key, into: &result)
      }
    case .object(let dict):
      guard !dict.isEmpty else {
        // RFC 6901 §4: empty objects are flattened to null
        result[prefix] = JSON.null
        return
      }
      for (key, value) in dict {
        // RFC 6901 §4: escape ~ as ~0 and / as ~1 in key segments
        let escaped =
          key
          .replacingOccurrences(of: "~", with: "~0")
          .replacingOccurrences(of: "/", with: "~1")
        let fullKey = prefix.isEmpty ? "/\(escaped)" : "\(prefix)/\(escaped)"
        value.flattenInternal(prefix: fullKey, into: &result)
      }
    }
  }

  /// Reconstructs a nested JSON value from a flattened object with JSON Pointer keys.
  ///
  /// Keys can be in either `/a/b/c` format (with leading `/`) or `a/b/c` format
  /// (without leading `/`). Both are supported.
  ///
  /// All values in the flattened object must be primitive JSON types (string,
  /// number, boolean, or null). Non-object input or non-primitive values
  /// cause a thrown `FlattenError`.
  ///
  /// - Returns: A nested `JSON` value reconstructed from the flat keys.
  /// - Throws: `FlattenError.notObject` if input is not an object.
  ///   `FlattenError.notPrimitive` if any value is not primitive.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let flat = JSON.object([
  ///   "/a/b": .number(.integer(1)),
  ///   "/a/c": .number(.integer(2))
  /// ])
  /// let nested = try flat.unflatten()
  /// // nested["a"]["b"] == 1
  /// // nested["a"]["c"] == 2
  /// ```
  public func unflatten() throws -> JSON {
    guard case .object(let dict) = storage else {
      throw FlattenError.notObject
    }

    // Validate all values are primitive (mirrors nlohmann/json behavior)
    for (key, value) in dict {
      guard value.isPrimitive else {
        throw FlattenError.notPrimitive(key)
      }
    }

    // Build the nested structure by recursively inserting each path
    var root: JSON = .object(OrderedDictionary<String, JSON>())
    let entries = dict.sorted { $0.key < $1.key }

    for (key, value) in entries {
      let segments = key.split(separator: "/", omittingEmptySubsequences: false).map(
        String.init)
      // If the first segment is empty (key starts with "/"), drop it.
      // Otherwise keep all segments.
      var parts =
        segments.first?.isEmpty == true
        ? segments.dropFirst().filter { !$0.isEmpty }
        : segments.filter { !$0.isEmpty }
      guard !parts.isEmpty else { continue }
      // RFC 6901 §4: unescape ~0 (tilde) and ~1 (slash) in each segment.
      // Must iterate sequentially to handle overlapping ~00 (double tilde).
      parts = parts.map { unescapeJSONPointerSegment($0) }
      JSON.setJSONPointerPath(into: &root, parts: Array(parts), value: value)
    }

    return root
  }
}
