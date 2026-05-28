import Foundation
import OrderedCollections

// MARK: - JSON Patch (RFC 6902)

extension JSON {
  /// Applies a JSON Patch (RFC 6902) to this value and returns the patched result.
  ///
  /// The original value is not mutated — a copy is made and returned.
  ///
  /// - Parameter patchValue: A JSON array of patch operations.
  /// - Returns: A new `JSON` value with all patch operations applied.
  /// - Throws: `JSONError.formatError` if the patch is malformed or an operation fails.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let json = JSON.object(["foo": .string("bar")])
  /// let patch = JSON.array([
  ///   .object(["op": .string("add"), "path": .string("/baz"), "value": .string("qux")])
  /// ])
  /// let patched = try json.patch(patch)
  /// ```
  public func patch(_ patchValue: JSON) throws -> JSON {
    var copy = self
    try copy.patching(patchValue)
    return copy
  }

  /// Applies a JSON Patch (RFC 6902) in-place, mutating this value.
  ///
  /// - Parameter patchValue: A JSON array of patch operations.
  /// - Throws: `JSONError.formatError` if the patch is malformed or an operation fails.
  public mutating func patching(_ patchValue: JSON) throws {
    guard case .array(let operations) = patchValue.storage else {
      throw JSONError.formatError("Patch must be an array of operations")
    }
    for operation in operations {
      try applyPatchOperation(operation)
    }
  }

  private mutating func applyPatchOperation(_ op: JSON) throws {
    guard case .object(let dict) = op.storage else {
      throw JSONError.formatError("Each operation must be an object")
    }
    guard let opStr = dict["op"]?.stringValue else {
      throw JSONError.formatError("Missing 'op' field")
    }
    guard let pathStr = dict["path"]?.stringValue else {
      throw JSONError.formatError("Missing 'path' field")
    }

    let segments = parsePatchPath(pathStr)

    switch opStr {
    case "add":
      guard let value = dict["value"] else {
        throw JSONError.formatError("Missing 'value' field for add")
      }
      self = try settingValue(at: segments, value: value, in: self, isAdd: true)

    case "remove":
      self = try removingValue(at: segments, from: self)

    case "replace":
      guard let value = dict["value"] else {
        throw JSONError.formatError("Missing 'value' field for replace")
      }
      self = try settingValue(at: segments, value: value, in: self, isAdd: false)

    case "copy":
      guard let fromStr = dict["from"]?.stringValue else {
        throw JSONError.formatError("Missing 'from' field for copy")
      }
      let fromValue = try resolveRequiredPointer(segments: parsePatchPath(fromStr), in: self)
      self = try settingValue(at: segments, value: fromValue, in: self, isAdd: true)

    case "move":
      guard let fromStr = dict["from"]?.stringValue else {
        throw JSONError.formatError("Missing 'from' field for move")
      }
      let fromSegments = parsePatchPath(fromStr)
      let fromValue = try resolveRequiredPointer(segments: fromSegments, in: self)
      self = try removingValue(at: fromSegments, from: self)
      self = try settingValue(at: segments, value: fromValue, in: self, isAdd: true)

    case "test":
      guard let value = dict["value"] else {
        throw JSONError.formatError("Missing 'value' field for test")
      }
      let current = try resolveRequiredPointer(segments: segments, in: self)
      if current != value {
        throw JSONError.formatError("Test failed: value mismatch")
      }

    default:
      throw JSONError.formatError("Unknown operation: \(opStr)")
    }
  }

  private func parsePatchPath(_ path: String) -> [String] {
    if path.isEmpty || path == "/" { return [] }
    return path.dropFirst().split(separator: "/", omittingEmptySubsequences: false).map {
      $0.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
    }
  }

  private func resolveRequiredPointer(segments: [String], in json: JSON) throws -> JSON {
    guard let value = resolvePointer(segments: segments, in: json) else {
      throw JSONError.formatError("Path not found")
    }
    return value
  }

  private func resolvePointer(segments: [String], in json: JSON) -> JSON? {
    var current = json
    for segment in segments {
      if segment == "-" { return nil }  // '-' is only valid as add target, not resolve
      if let index = Int(segment) {
        guard case .array(let arr) = current.storage,
          index >= 0, index < arr.count
        else { return nil }
        current = arr[index]
      } else {
        guard case .object(let dict) = current.storage,
          let value = dict[segment]
        else { return nil }
        current = value
      }
    }
    return current
  }

  /// Returns a new JSON value with `value` set at the given path.
  /// Uses recursive tree rebuilding to avoid complex parent mutation.
  /// - `isAdd`: if true, inserts into arrays; if false, replaces existing elements.
  private func settingValue(at segments: [String], value: JSON, in json: JSON, isAdd: Bool) throws
    -> JSON
  {
    guard !segments.isEmpty else { return value }
    return try traverseAndSet(json, segments: segments, index: 0, value: value, isAdd: isAdd)
  }

  /// Returns a new JSON value with the value at the given path removed.
  private func removingValue(at segments: [String], from json: JSON) throws -> JSON {
    guard !segments.isEmpty else { return .null }
    return try traverseAndRemove(json, segments: segments, index: 0)
  }

  /// Recursively walks the tree, rebuilding it. At the target leaf, applies the value.
  /// - `isAdd`: if true and target is an array index, insert (not replace). If the segment
  ///   is `"-"`, append to the end of the array.
  private func traverseAndSet(
    _ json: JSON, segments: [String], index: Int, value: JSON, isAdd: Bool
  ) throws -> JSON {
    let segment = segments[index]
    let isLast = index == segments.count - 1

    if segment == "-" {
      guard case .array(let arr) = json.storage else {
        throw JSONError.formatError("Cannot append to non-array")
      }
      if isLast {
        var copy = arr
        copy.append(value)
        return .array(copy)
      } else {
        throw JSONError.formatError("Cannot traverse beyond '-' append marker")
      }
    }

    if let idx = Int(segment) {
      guard case .array(let arr) = json.storage else {
        throw JSONError.formatError("Cannot index into non-array")
      }
      if isLast {
        var copy = arr
        if isAdd {
          if idx > copy.count {
            throw JSONError.formatError("Array index out of bounds for add")
          } else if idx == copy.count {
            copy.append(value)
          } else {
            copy.insert(value, at: idx)
          }
        } else {
          guard idx >= 0, idx < copy.count else {
            throw JSONError.formatError("Array index out of bounds for replace")
          }
          copy[idx] = value
        }
        return .array(copy)
      } else {
        guard idx >= 0, idx < arr.count else {
          throw JSONError.formatError("Array index out of bounds")
        }
        let updatedChild = try traverseAndSet(
          arr[idx], segments: segments, index: index + 1, value: value, isAdd: isAdd
        )
        var copy = arr
        copy[idx] = updatedChild
        return .array(copy)
      }
    } else {
      guard case .object(var dict) = json.storage else {
        throw JSONError.formatError("Cannot key into non-object")
      }
      if isLast {
        dict[segment] = value
        return .object(dict)
      } else {
        guard let child = dict[segment] else {
          throw JSONError.formatError("Key not found: \(segment)")
        }
        let updatedChild = try traverseAndSet(
          child, segments: segments, index: index + 1, value: value, isAdd: isAdd
        )
        dict[segment] = updatedChild
        return .object(dict)
      }
    }
  }

  /// Recursively walks the tree, rebuilding it. At the target leaf, removes the value.
  private func traverseAndRemove(_ json: JSON, segments: [String], index: Int) throws -> JSON {
    let segment = segments[index]
    let isLast = index == segments.count - 1

    if let idx = Int(segment) {
      guard case .array(let arr) = json.storage else {
        throw JSONError.formatError("Cannot index into non-array for remove")
      }
      guard idx >= 0, idx < arr.count else {
        throw JSONError.formatError("Array index out of bounds for remove")
      }
      if isLast {
        var copy = arr
        copy.remove(at: idx)
        return .array(copy)
      } else {
        let updatedChild = try traverseAndRemove(arr[idx], segments: segments, index: index + 1)
        var copy = arr
        copy[idx] = updatedChild
        return .array(copy)
      }
    } else {
      guard case .object(var dict) = json.storage else {
        throw JSONError.formatError("Cannot key into non-object for remove")
      }
      if isLast {
        guard dict.keys.contains(segment) else {
          throw JSONError.formatError("Key not found: \(segment)")
        }
        dict.removeValue(forKey: segment)
        return .object(dict)
      } else {
        guard let child = dict[segment] else {
          throw JSONError.formatError("Key not found: \(segment)")
        }
        let updatedChild = try traverseAndRemove(child, segments: segments, index: index + 1)
        dict[segment] = updatedChild
        return .object(dict)
      }
    }
  }
}

// MARK: - JSON Diff

extension JSON {
  /// Creates a JSON Patch (RFC 6902) that transforms `source` into `target`.
  ///
  /// The diff is computed recursively:
  /// - Objects: keys that differ generate add/remove/replace operations.
  /// - Arrays: element-by-element comparison with add/remove for excess.
  /// - Other types: direct replace if different.
  ///
  /// - Parameters:
  ///   - source: The original JSON value.
  ///   - target: The desired JSON value.
  /// - Returns: A JSON array of patch operations.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let a = JSON.object(["a": .number(.integer(1))])
  /// let b = JSON.object(["a": .number(.integer(2))])
  /// let patch = JSON.diff(a, b)  // [{"op":"replace","path":"/a","value":2}]
  /// ```
  public static func diff(_ source: JSON, _ target: JSON) -> JSON {
    var operations: [JSON] = []
    diffInternal(source: source, target: target, path: "", operations: &operations)
    return .array(operations)
  }

  private static func diffInternal(
    source: JSON, target: JSON, path: String, operations: inout [JSON]
  ) {
    if source == target { return }

    switch (source.storage, target.storage) {
    case (.object(let s), .object(let t)):
      let sourceKeys = Set(s.keys)
      let targetKeys = Set(t.keys)

      for key in sourceKeys.subtracting(targetKeys) {
        let opPath = path.isEmpty ? "/\(key)" : "\(path)/\(key)"
        operations.append(
          .object([
            "op": .string("remove"),
            "path": .string(opPath),
          ])
        )
      }

      for key in targetKeys {
        let opPath = path.isEmpty ? "/\(key)" : "\(path)/\(key)"
        if let sv = s[key], let tv = t[key] {
          if sv != tv {
            if tv.isObject || tv.isArray {
              diffInternal(source: sv, target: tv, path: opPath, operations: &operations)
            } else {
              operations.append(
                .object([
                  "op": .string("replace"),
                  "path": .string(opPath),
                  "value": tv,
                ])
              )
            }
          }
        } else {
          operations.append(
            .object([
              "op": .string("add"),
              "path": .string(opPath),
              "value": t[key]!,
            ])
          )
        }
      }

    case (.array(let s), .array(let t)):
      let minCount = Swift.min(s.count, t.count)
      for i in 0..<minCount {
        let opPath = path.isEmpty ? "/\(i)" : "\(path)/\(i)"
        if s[i] != t[i] {
          if t[i].isObject || t[i].isArray {
            diffInternal(source: s[i], target: t[i], path: opPath, operations: &operations)
          } else {
            operations.append(
              .object([
                "op": .string("replace"),
                "path": .string(opPath),
                "value": t[i],
              ])
            )
          }
        }
      }
      if s.count > minCount {
        for i in minCount..<s.count {
          let opPath = path.isEmpty ? "/\(i)" : "\(path)/\(i)"
          operations.append(
            .object([
              "op": .string("remove"),
              "path": .string(opPath),
            ])
          )
        }
      }
      if t.count > minCount {
        for i in minCount..<t.count {
          let opPath = path.isEmpty ? "/\(i)" : "\(path)/\(i)"
          operations.append(
            .object([
              "op": .string("add"),
              "path": .string(opPath),
              "value": t[i],
            ])
          )
        }
      }

    default:
      let targetPath = path.isEmpty ? "" : path
      operations.append(
        .object([
          "op": .string("replace"),
          "path": .string(targetPath),
          "value": target,
        ])
      )
    }
  }
}
