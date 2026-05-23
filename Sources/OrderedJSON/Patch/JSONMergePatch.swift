import Foundation
import OrderedCollections

// MARK: - JSON Merge Patch (RFC 7396)

extension JSON {
  /// Applies a JSON Merge Patch (RFC 7396) to this value.
  /// - Parameter patch: The merge patch to apply. `nil` removes the value (sets to null).
  /// - Returns: A new merged JSON value.
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
