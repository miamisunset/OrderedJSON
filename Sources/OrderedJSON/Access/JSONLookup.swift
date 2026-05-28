import Foundation
import OrderedCollections

extension JSON {
  // MARK: - contains

  /// Returns `true` if a JSON object contains the given key.
  ///
  /// For non-object values, always returns `false`.
  ///
  /// - Parameter key: The key to look up.
  /// - Returns: `true` if the key exists in this object.
  public func contains(key: String) -> Bool {
    guard case .object(let dict) = storage else { return false }
    return dict.keys.contains(key)
  }

  /// Returns `true` if a JSON array contains the given element.
  ///
  /// Uses `==` for comparison. For non-array values, always returns `false`.
  ///
  /// - Parameter element: The element to look up.
  /// - Returns: `true` if the element exists in this array.
  public func contains(element: JSON) -> Bool {
    guard case .array(let arr) = storage else { return false }
    return arr.contains(element)
  }

  // MARK: - find

  /// Finds a value by key in a JSON object.
  ///
  /// Returns `nil` if the key doesn't exist or if the value is not an object.
  /// - Parameter key: The key to look up.
  /// - Returns: The value for the key, or `nil`.
  public func find(key: String) -> JSON? {
    guard case .object(let dict) = storage else { return nil }
    return dict[key]
  }
}
