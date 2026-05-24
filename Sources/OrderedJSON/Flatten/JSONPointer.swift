import Foundation
import OrderedCollections

/// A JSON Pointer (RFC 6901) reference into a JSON value.
///
/// JSON Pointers are string expressions that identify a specific value
/// within a JSON document. They start with `/` and use `~0` for `~` and
/// `~1` for `/` escaping.
///
/// ## Example
///
/// ```swift
/// let ptr = try JSONPointer("/foo/bar/0")
/// let value = ptr.resolve(json)  // value at path /foo/bar/0
/// ptr.set(into: &json, value: .number(.integer(42)))
/// ```
public struct JSONPointer: Hashable, Sendable {
  /// The path segments of this pointer.
  /// For root (`""`), this is an empty array.
  public let segments: [String]

  /// Creates a pointer from a JSON Pointer string.
  ///
  /// The path must start with `/` or be empty (root pointer).
  /// Escapes `~0` (tilde) and `~1` (forward slash) are decoded.
  ///
  /// - Parameter path: A JSON Pointer string, e.g. `"/foo/bar"`.
  /// - Throws: `JSONError.invalidString` if the path doesn't start with `/`.
  public init(_ path: String) throws {
    // Parse the path into segments
    guard path.hasPrefix("/") || path.isEmpty else {
      throw JSONError.invalidString  // placeholder — define proper error
    }
    if path.isEmpty {
      segments = []
      return
    }
    // RFC 6901 §4: decode ~0 (tilde) first, then ~1 (slash).
    // Order matters: ~01 must decode as ~0→~ then ~1→/ → "/"
    // Uses sequential iteration to handle overlapping ~00 (double tilde).
    segments = path.dropFirst().split(separator: "/", omittingEmptySubsequences: false).map {
      unescapeJSONPointerSegment(String($0))
    }
  }

  /// Creates a pointer from an array of segments.
  /// - Parameter segments: The path segments.
  public init(segments: [String]) {
    self.segments = segments
  }

  /// Resolve this pointer against a JSON value.
  ///
  /// For each segment, if the segment is parseable as an integer, it's
  /// used as an array index; otherwise it's used as an object key.
  ///
  /// - Parameter json: The JSON value to resolve against.
  /// - Returns: The value at the pointer path, or `nil` if any segment
  ///   doesn't match.
  public func resolve(_ json: JSON) -> JSON? {
    var current = json
    for segment in segments {
      if let index = Int(segment) {
        guard case .array(let arr) = current.storage else { return nil }
        guard index >= 0, index < arr.count else { return nil }
        current = arr[index]
      } else {
        guard case .object(let dict) = current.storage else { return nil }
        guard let value = dict[segment] else { return nil }
        current = value
      }
    }
    return current
  }

  /// Set a value at this pointer path, creating intermediate objects/arrays as needed.
  ///
  /// If the pointer is root (empty segments), the entire value is replaced.
  /// Intermediate objects/arrays are created automatically when a segment
  /// references a non-existent key or index.
  ///
  /// - Parameters:
  ///   - json: The JSON value to modify (in-out).
  ///   - value: The value to set at the pointer path.
  public func set(into json: inout JSON, value: JSON) {
    guard !segments.isEmpty else {
      json = value
      return
    }
    JSON.setJSONPointerPath(into: &json, parts: segments, value: value)
  }
}

// MARK: - Internal helper (reused from JSONFlatten)

extension JSON {
  /// Recursively sets a value at a path of segments, creating intermediate objects/arrays.
  ///
  /// This is the same logic used by `unflatten()` and is shared with `JSONPointer`.
  /// - Parameters:
  ///   - json: The JSON value to modify (in-out).
  ///   - parts: The remaining path segments.
  ///   - value: The value to set at the leaf.
  internal static func setJSONPointerPath(into json: inout JSON, parts: [String], value: JSON) {
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

/// Decodes RFC 6901 escape sequences (~0 → ~, ~1 → /) in a single segment.
/// Uses sequential iteration to handle overlapping sequences like ~00.
internal func unescapeJSONPointerSegment(_ segment: String) -> String {
  // First pass: decode ~0 to ~, leave ~1 untouched
  var decoded = ""
  var i = segment.startIndex
  while i < segment.endIndex {
    let remaining = segment[i...]
    if remaining.hasPrefix("~0") {
      decoded.append("~")
      segment.formIndex(&i, offsetBy: 2)
    } else if remaining.hasPrefix("~1") {
      decoded.append("~1")
      segment.formIndex(&i, offsetBy: 2)
    } else {
      decoded.append(segment[i])
      segment.formIndex(&i, offsetBy: 1)
    }
  }
  // Second pass: decode ~1 to /
  i = decoded.startIndex
  var result = ""
  while i < decoded.endIndex {
    let remaining = decoded[i...]
    if remaining.hasPrefix("~1") {
      result.append("/")
      decoded.formIndex(&i, offsetBy: 2)
    } else {
      result.append(decoded[i])
      decoded.formIndex(&i, offsetBy: 1)
    }
  }
  return result
}
