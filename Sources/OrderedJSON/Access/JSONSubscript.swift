import Foundation
import OrderedCollections

extension JSON {
  // MARK: - Key subscript

  /// Accesses the value for the given key in a JSON object.
  ///
  /// When getting, returns `nil` if the key doesn't exist or if the value
  /// is not an object. When setting, if `newValue` is non-nil the key is
  /// updated/inserted; if `nil` the key is removed.
  ///
  /// - Parameter key: The object key.
  /// - Returns: The value for the key, or `nil`.
  public subscript(key: String) -> JSON? {
    get {
      guard case .object(let dict) = storage else { return nil }
      return dict[key]
    }
    set {
      guard case .object(var dict) = storage else {
        // For mutating setter, we need to handle the case where self is not an object
        // This silently fails or could be made to throw; matching nlohmann/json behavior
        return
      }
      if let value = newValue {
        dict[key] = value
      } else {
        dict.removeValue(forKey: key)
      }
      storage = .object(dict)
    }
  }

  // MARK: - Index subscript

  /// Accesses the element at the given index in a JSON array.
  ///
  /// When getting, returns `nil` if the index is out of bounds or if the
  /// value is not an array. When setting, if `newValue` is non-nil the
  /// element is replaced; if `nil` the element is removed.
  ///
  /// - Parameter index: The array index.
  /// - Returns: The element at the index, or `nil`.
  public subscript(index: Int) -> JSON? {
    get {
      guard case .array(let arr) = storage else { return nil }
      guard index >= 0, index < arr.count else { return nil }
      return arr[index]
    }
    set {
      guard case .array(var arr) = storage else { return }
      guard index >= 0, index < arr.count else { return }
      if let value = newValue {
        arr[index] = value
      } else {
        arr.remove(at: index)
      }
      storage = .array(arr)
    }
  }

  // MARK: - at() throwing variants

  /// Returns the value for the given key, throwing if the key is missing
  /// or if the value is not an object.
  ///
  /// - Parameter key: The object key.
  /// - Returns: The value for the key.
  /// - Throws: `JSONError.typeError` if not an object,
  ///   `JSONError.keyNotFound` if the key is missing.
  public func at(_ key: String) throws -> JSON {
    guard case .object(let dict) = storage else {
      throw JSONError.typeError(expected: "object", actual: typeName)
    }
    guard let value = dict[key] else {
      throw JSONError.keyNotFound(key)
    }
    return value
  }

  /// Returns the element at the given index, throwing if the index is
  /// out of bounds or if the value is not an array.
  ///
  /// - Parameter index: The array index.
  /// - Returns: The element at the index.
  /// - Throws: `JSONError.typeError` if not an array,
  ///   `JSONError.indexOutOfBounds` if the index is invalid.
  public func at(_ index: Int) throws -> JSON {
    guard case .array(let arr) = storage else {
      throw JSONError.typeError(expected: "array", actual: typeName)
    }
    guard index >= 0, index < arr.count else {
      throw JSONError.indexOutOfBounds(index)
    }
    return arr[index]
  }

  // MARK: - value() with default

  /// Returns the value for the given key, or a default value if the key
  /// doesn't exist or if the value is not an object.
  ///
  /// - Parameters:
  ///   - key: The object key.
  ///   - defaultValue: The value to return if the key is missing.
  /// - Returns: The value for the key, or `defaultValue`.
  public func value(_ key: String, default defaultValue: JSON) -> JSON {
    guard case .object(let dict) = storage else { return defaultValue }
    return dict[key] ?? defaultValue
  }
}
