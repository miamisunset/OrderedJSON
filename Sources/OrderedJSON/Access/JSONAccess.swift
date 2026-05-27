import Foundation
import OrderedCollections

extension JSON {
  // MARK: - Capacity

  /// Returns the number of elements in an object or array, or 0 for primitives.
  ///
  /// For objects, returns the number of key-value pairs.
  /// For arrays, returns the number of elements.
  /// For null, boolean, number, and string values, returns 0.
  public var count: Int {
    switch storage {
    case .object(let dict): return dict.count
    case .array(let arr): return arr.count
    case .null, .boolean, .number, .string: return 0
    }
  }

  /// Returns `true` if the value is empty or null.
  ///
  /// An object with no keys or an array with no elements is empty.
  /// Null is considered empty. Booleans, numbers, and strings are not empty.
  public var isEmpty: Bool {
    switch storage {
    case .object(let dict): return dict.isEmpty
    case .array(let arr): return arr.isEmpty
    case .null: return true
    case .boolean, .number, .string: return false
    }
  }

  /// The maximum number of elements a JSON value can contain.
  /// Always returns `Int.max`.
  public var maxCount: Int {
    Int.max
  }

  // MARK: - First / Last

  /// Returns the first element of an array or the first value of an object,
  /// or `nil` for primitives.
  ///
  /// For arrays, returns the element at index 0.
  /// For objects, returns the value associated with the first key (insertion order).
  /// For primitives, returns `nil`.
  public var first: JSON? {
    switch storage {
    case .array(let arr): return arr.first
    case .object(let dict):
      guard let firstKey = dict.keys.first else { return nil }
      return dict[firstKey]
    case .null, .boolean, .number, .string: return nil
    }
  }

  /// Returns the last element of an array or the last value of an object,
  /// or `nil` for primitives.
  ///
  /// For arrays, returns the last element.
  /// For objects, returns the value associated with the last key (insertion order).
  /// For primitives, returns `nil`.
  public var last: JSON? {
    switch storage {
    case .array(let arr): return arr.last
    case .object(let dict):
      guard let lastKey = dict.keys.last else { return nil }
      return dict[lastKey]
    case .null, .boolean, .number, .string: return nil
    }
  }

  // MARK: - Keys

  /// Returns the keys of an object value in insertion order, or `nil` for non-objects.
  ///
  /// For objects, returns the ordered key array.
  /// For arrays and primitives, returns `nil`.
  public var objectKeys: [String]? {
    guard case .object(let dict) = storage else { return nil }
    return Array(dict.keys)
  }

  // MARK: - Array access

  /// Returns the elements of an array value, or `nil` for non-arrays.
  ///
  /// For arrays, returns the ordered array of JSON elements.
  /// For objects and primitives, returns `nil`.
  public var arrayValue: [JSON]? {
    guard case .array(let arr) = storage else { return nil }
    return arr
  }

  // MARK: - Object access

  /// Returns the key-value pairs of an object value, or `nil` for non-objects.
  ///
  /// For objects, returns the ordered dictionary preserving insertion order.
  /// For arrays and primitives, returns `nil`.
  public var objectValue: OrderedDictionary<String, JSON>? {
    guard case .object(let dict) = storage else { return nil }
    return dict
  }
}
