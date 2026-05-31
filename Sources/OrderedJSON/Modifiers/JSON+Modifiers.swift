import OrderedCollections

extension JSON {
  // MARK: - clear

  /// Removes all elements from an object or array.
  ///
  /// For objects, removes all key-value pairs (leaving an empty object).
  /// For arrays, removes all elements (leaving an empty array).
  /// For primitives, this is a no-op.
  public mutating func clear() {
    self = cleared()
  }

  /// Returns a copy with all elements removed from an object or array.
  ///
  /// For objects, returns an empty object. For arrays, returns an empty array.
  /// For primitives, returns an identical copy (no-op).
  public func cleared() -> JSON {
    switch storage {
    case .object:
      return JSON.object(OrderedDictionary<String, JSON>())
    case .array:
      return JSON.array([])
    case .null, .boolean, .number, .string:
      return self
    }
  }

  // MARK: - remove(key)

  /// Removes a key-value pair from a JSON object.
  ///
  /// If the value is not an object or the key doesn't exist, this is a no-op.
  /// - Parameter key: The key to remove.
  public mutating func remove(key: String) {
    guard case .object(var dict) = storage else { return }
    dict.removeValue(forKey: key)
    storage = .object(dict)
  }

  // MARK: - remove(at:)

  /// Removes an element at the given index from a JSON array.
  ///
  /// If the value is not an array or the index is out of bounds, this is a no-op.
  /// - Parameter index: The index of the element to remove.
  public mutating func remove(at index: Int) {
    guard case .array(var arr) = storage else { return }
    guard index >= 0, index < arr.count else { return }
    arr.remove(at: index)
    storage = .array(arr)
  }

  // MARK: - append

  /// Appends a value to the end of a JSON array.
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

  // MARK: - setDefault (object, insert if key absent)

  /// Inserts a key-value pair into a JSON object only if the key doesn't
  /// already exist.
  ///
  /// If the value is not an object, this is a no-op.
  /// - Parameters:
  ///   - key: The key to insert.
  ///   - defaultValue: The value to set if the key is absent (auto-closure).
  public mutating func setDefault(key: String, _ defaultValue: @autoclosure () -> JSON) {
    guard case .object(var dict) = storage else { return }
    if dict[key] == nil {
      dict[key] = defaultValue()
    }
    storage = .object(dict)
  }

  // MARK: - update (merge object keys)

  /// Merges the key-value pairs from `other` into this JSON object.
  ///
  /// Mirrors `nlohmann::basic_json::update(const_reference j, bool merge_objects)`.
  ///
  /// When `mergingNested` is `false` (default), existing keys are overwritten
  /// and new keys are added. When `mergingNested` is `true`, objects at the
  /// same key are recursively merged instead of replaced — useful for merging
  /// nested configuration trees.
  ///
  /// At the top level, if either the receiver or `other` is not an object,
  /// this is a no-op. Inside recursion, only object-vs-object keys are
  /// merged; any other type (primitive, array, null) overwrites.
  /// - Parameters:
  ///   - other: The object whose keys to merge in.
  ///   - mergingNested: If `true`, recursively merge nested objects at the
  ///     same key. Defaults to `false`.
  public mutating func update(with other: JSON, mergingNested: Bool = false) {
    guard case .object(var dict) = storage else { return }
    guard case .object(let otherDict) = other.storage else { return }
    for (key, value) in otherDict {
      if mergingNested,
        let existing = dict[key],
        existing.isObject,
        value.isObject
      {
        var merged = existing
        merged.update(with: value, mergingNested: true)
        dict[key] = merged
      } else {
        dict[key] = value
      }
    }
    storage = .object(dict)
  }

  /// Returns a copy with `other`'s keys merged into this JSON object.
  ///
  /// When `mergingNested` is `false` (default), existing keys are overwritten
  /// and new keys are added. When `mergingNested` is `true`, objects at the
  /// same key are recursively merged instead of replaced.
  /// - Parameters:
  ///   - other: The object whose keys to merge in.
  ///   - mergingNested: If `true`, recursively merge nested objects at the
  ///     same key. Defaults to `false`.
  /// - Returns: A new JSON object with `other` merged in.
  public func updated(with other: JSON, mergingNested: Bool = false) -> JSON {
    var copy = self
    copy.update(with: other, mergingNested: mergingNested)
    return copy
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
