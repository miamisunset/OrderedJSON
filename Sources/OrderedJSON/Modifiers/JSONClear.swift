import Foundation
import OrderedCollections

extension JSON {
  // MARK: - clear

  /// Removes all elements from an object or array.
  ///
  /// For objects, removes all key-value pairs (leaving an empty object).
  /// For arrays, removes all elements (leaving an empty array).
  /// For primitives, this is a no-op.
  public mutating func clear() {
    switch storage {
    case .object:
      storage = .object(OrderedDictionary<String, JSON>())
    case .array:
      storage = .array([])
    case .null, .boolean, .number, .string:
      break  // no-op for primitives
    }
  }

  // MARK: - erase(key)

  /// Removes a key-value pair from a JSON object.
  ///
  /// If the value is not an object or the key doesn't exist, this is a no-op.
  /// - Parameter key: The key to remove.
  public mutating func erase(_ key: String) {
    guard case .object(var dict) = storage else { return }
    dict.removeValue(forKey: key)
    storage = .object(dict)
  }

  // MARK: - erase(index)

  /// Removes an element at the given index from a JSON array.
  ///
  /// If the value is not an array or the index is out of bounds, this is a no-op.
  /// - Parameter index: The index of the element to remove.
  public mutating func erase(_ index: Int) {
    guard case .array(var arr) = storage else { return }
    guard index >= 0, index < arr.count else { return }
    arr.remove(at: index)
    storage = .array(arr)
  }

  // MARK: - append (push_back)

  /// Appends a value to the end of a JSON array (equivalent to `push_back`).
  ///
  /// If the value is not an array, this is a no-op.
  /// - Parameter value: The value to append.
  public mutating func append(_ value: JSON) {
    guard case .array(var arr) = storage else { return }
    arr.append(value)
    storage = .array(arr)
  }

  // MARK: - insert at index

  /// Inserts a value at the given index in a JSON array.
  ///
  /// If the value is not an array or the index is out of bounds, this is a no-op.
  /// - Parameters:
  ///   - value: The value to insert.
  ///   - index: The insertion index.
  public mutating func insert(_ value: JSON, at index: Int) {
    guard case .array(var arr) = storage else { return }
    guard index >= 0, index <= arr.count else { return }
    arr.insert(value, at: index)
    storage = .array(arr)
  }

  // MARK: - emplace (array)

  /// Appends a value to a JSON array (equivalent to `append`).
  ///
  /// Provided for compatibility with nlohmann/json's `emplace_back`.
  /// If the value is not an array, this is a no-op.
  /// - Parameter value: The value to append.
  public mutating func emplace(_ value: JSON) {
    guard case .array(var arr) = storage else { return }
    arr.append(value)
    storage = .array(arr)
  }

  // MARK: - emplace (object, insert if key absent)

  /// Inserts a key-value pair into a JSON object only if the key doesn't
  /// already exist.
  ///
  /// If the value is not an object, this is a no-op.
  /// - Parameters:
  ///   - key: The key to insert.
  ///   - defaultValue: The value to set if the key is absent (auto-closure).
  public mutating func emplace(key: String, default defaultValue: @autoclosure () -> JSON) {
    guard case .object(var dict) = storage else { return }
    if dict[key] == nil {
      dict[key] = defaultValue()
    }
    storage = .object(dict)
  }

  // MARK: - update (merge object keys)

  /// Merges the key-value pairs from `other` into this JSON object.
  ///
  /// When `mergeObjects` is `false` (default), existing keys are overwritten
  /// and new keys are added. When `mergeObjects` is `true`, objects at the
  /// same key are recursively merged instead of replaced — useful for merging
  /// nested configuration trees.
  ///
  /// If either value is not an object, this is a no-op.
  /// - Parameters:
  ///   - other: The object whose keys to merge in.
  ///   - mergeObjects: If `true`, recursively merge nested objects at the
  ///     same key. Defaults to `false`.
  public mutating func update(with other: JSON, mergeObjects: Bool = false) {
    guard case .object(var dict) = storage else { return }
    guard case .object(let otherDict) = other.storage else { return }
    for (key, value) in otherDict {
      if mergeObjects,
        let existing = dict[key],
        existing.isObject,
        value.isObject
      {
        var merged = existing
        merged.update(with: value, mergeObjects: true)
        dict[key] = merged
      } else {
        dict[key] = value
      }
    }
    storage = .object(dict)
  }

  // MARK: - swap

  /// Exchanges this value with another JSON value.
  /// - Parameter other: The value to swap with (modified in-place).
  public mutating func swap(with other: inout JSON) {
    let temp = self
    self = other
    other = temp
  }
}
