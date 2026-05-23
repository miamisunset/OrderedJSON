import Foundation
import OrderedCollections

extension JSON {
  /// Flattens nested JSON into a flat object with JSON Pointer keys (`/a/b/c`).
  ///
  /// Each leaf value is mapped to a JSON Pointer path. Empty objects and
  /// arrays produce no entries. Non-object roots return `self`.
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
      guard !elements.isEmpty else { return }
      for (index, element) in elements.enumerated() {
        let key = prefix.isEmpty ? "/\(index)" : "\(prefix)/\(index)"
        element.flattenInternal(prefix: key, into: &result)
      }
    case .object(let dict):
      guard !dict.isEmpty else { return }
      for (key, value) in dict {
        let fullKey = prefix.isEmpty ? "/\(key)" : "\(prefix)/\(key)"
        value.flattenInternal(prefix: fullKey, into: &result)
      }
    }
  }

  /// Reconstructs a nested JSON value from a flattened object with JSON Pointer keys.
  ///
  /// Keys can be in either `/a/b/c` format (with leading `/`) or `a/b/c` format
  /// (without leading `/`). Both are supported.
  ///
  /// - Returns: A nested `JSON` value reconstructed from the flat keys.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let flat = JSON.object([
  ///   "/a/b": .number(.integer(1)),
  ///   "/a/c": .number(.integer(2))
  /// ])
  /// let nested = flat.unflatten()
  /// // nested["a"]["b"] == 1
  /// // nested["a"]["c"] == 2
  /// ```
  public func unflatten() -> JSON {
    guard case .object(let dict) = storage else { return self }

    // Build the nested structure by recursively inserting each path
    var root: JSON = .object(OrderedDictionary<String, JSON>())
    let entries = dict.sorted { $0.key < $1.key }

    for (key, value) in entries {
      let segments = key.split(separator: "/", omittingEmptySubsequences: false).map(
        String.init)
      // If the first segment is empty (key starts with "/"), drop it.
      // Otherwise keep all segments.
      let parts =
        segments.first?.isEmpty == true
        ? segments.dropFirst().filter { !$0.isEmpty }
        : segments.filter { !$0.isEmpty }
      guard !parts.isEmpty else { continue }
      JSON.setJSONPointerPath(into: &root, parts: Array(parts), value: value)
    }

    return root
  }
}
