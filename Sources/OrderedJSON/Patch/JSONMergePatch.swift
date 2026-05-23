import Foundation
import OrderedCollections

// MARK: - JSON Merge Patch (RFC 7396)

extension JSON {
  /// Applies a JSON Merge Patch (RFC 7396) to this value.
  ///
  /// Merge patches are simpler than JSON Patch — they are JSON objects
  /// where each key either:
  /// - Has a `null` value (removes the key from the target)
  /// - Has an object value (recursively merges into the existing object)
  /// - Has any other value (replaces or adds the key)
  ///
  /// If the patch itself is `null`, the target is replaced with `null` (removed).
  /// If the patch is not an object, it replaces the entire target.
  ///
  /// - Parameter patch: The merge patch to apply.
  /// - Returns: A new merged JSON value.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let target = JSON.object([
  ///   "a": .string("old"),
  ///   "b": .string("keep")
  /// ])
  /// let patch = JSON.object([
  ///   "a": .null,           // remove key "a"
  ///   "b": .string("updated"),  // update key "b"
  ///   "c": .number(.integer(3)) // add new key "c"
  /// ])
  /// let merged = target.mergePatch(patch)
  /// ```
  public func mergePatch(_ patch: JSON) -> JSON {
    return mergePatchInternal(target: self, patch: patch)
  }

  private func mergePatchInternal(target: JSON, patch: JSON) -> JSON {
    // If patch is null, the target is replaced with null (removed)
    if patch.isNull { return .null }

    // If patch is not an object, it replaces the target
    guard patch.isObject else { return patch }

    // If target is not an object, start with an empty object
    let targetDict: OrderedDictionary<String, JSON>
    if case .object(let dict) = target.storage {
      targetDict = dict
    } else {
      targetDict = [:]
    }

    guard case .object(let patchDict) = patch.storage else {
      return patch
    }

    var result = targetDict

    for (key, patchValue) in patchDict {
      if patchValue.isNull {
        // Remove the key
        result.removeValue(forKey: key)
      } else if patchValue.isObject, let existing = result[key] {
        // Recursive merge for object patches
        result[key] = mergePatchInternal(target: existing, patch: patchValue)
      } else {
        // Replace or add the value
        result[key] = patchValue
      }
    }

    return .object(result)
  }
}
