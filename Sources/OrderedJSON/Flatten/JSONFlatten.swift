import Foundation
import OrderedCollections

extension JSON {
  /// Flattens nested JSON into a flat object with JSON Pointer keys (`/a/b/c`).
  /// Returns a `JSON` object where each key is a JSON Pointer path and each value is a leaf value.
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

  /// Recursively sets a value at a path of segments, creating intermediate objects/arrays.
  private static func setJSONPointerPath(into json: inout JSON, parts: [String], value: JSON) {
    guard let first = parts.first else {
      json = value
      return
    }
    let rest = Array(parts.dropFirst())

    if let index = Int(first) {
      // Array path segment
      if case .array(var arr) = json.storage {
        while arr.count <= index {
          arr.append(JSON.null)
        }
        setJSONPointerPath(into: &arr[index], parts: rest, value: value)
        json.storage = .array(arr)
      } else {
        var arr = [JSON](repeating: JSON.null, count: index + 1)
        if rest.isEmpty {
          arr[index] = value
        } else {
          arr[index] = JSON.object(OrderedDictionary<String, JSON>())
          setJSONPointerPath(into: &arr[index], parts: rest, value: value)
        }
        json = .array(arr)
      }
    } else {
      // Object path segment
      if case .object(var dict) = json.storage {
        if rest.isEmpty {
          dict[first] = value
        } else {
          if dict[first] == nil {
            dict[first] = JSON.object(OrderedDictionary<String, JSON>())
          }
          setJSONPointerPath(into: &dict[first]!, parts: rest, value: value)
        }
        json.storage = .object(dict)
      } else {
        var dict = OrderedDictionary<String, JSON>()
        if rest.isEmpty {
          dict[first] = value
        } else {
          dict[first] = JSON.object(OrderedDictionary<String, JSON>())
          setJSONPointerPath(into: &dict[first]!, parts: rest, value: value)
        }
        json = .object(dict)
      }
    }
  }
}
