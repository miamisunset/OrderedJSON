import Foundation
import OrderedCollections

extension JSON: Sequence {
  /// Iterates over the elements of this JSON value.
  ///
  /// For arrays, yields each element in order.
  /// For objects, yields each value (not key-value pairs).
  /// For primitives, yields a single element (`self`).
  ///
  /// To iterate over key-value pairs of objects, use `items()` instead.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let json = JSON.array([.number(.integer(1)), .number(.integer(2))])
  /// for element in json { print(element) }  // 1, 2
  /// ```
  public func makeIterator() -> JSONIterator {
    switch storage {
    case .array(let arr):
      return JSONIterator(mode: .array(arr.makeIterator()))
    case .object(let dict):
      return JSONIterator(mode: .object(dict.makeIterator()))
    default:
      return JSONIterator(mode: .single(self))
    }
  }
}

/// An iterator over the elements of a `JSON` value.
///
/// Created by `JSON.makeIterator()`. Iterates array elements, object values,
/// or a single primitive value.
public struct JSONIterator: IteratorProtocol {
  enum Mode {
    case array(IndexingIterator<[JSON]>)
    case object(OrderedDictionary<String, JSON>.Iterator)
    case single(JSON)
    case empty
  }

  var mode: Mode
  var singleConsumed = false

  init(mode: Mode) {
    self.mode = mode
    singleConsumed = false
  }

  public mutating func next() -> JSON? {
    switch mode {
    case .array(var it):
      let result = it.next()
      mode = .array(it)
      return result
    case .object(var it):
      guard let (_, value) = it.next() else {
        mode = .empty
        return nil
      }
      mode = .object(it)
      return value
    case .single(let value):
      guard !singleConsumed else {
        mode = .empty
        return nil
      }
      singleConsumed = true
      return value
    case .empty:
      return nil
    }
  }
}

extension JSON {
  /// Returns an array of key-value pairs for objects, or an empty array for non-objects.
  ///
  /// Unlike `Sequence` iteration (which yields only values), `keyValuePairs()` yields
  /// both keys and values. The order matches insertion order.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let json = JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])
  /// for (key, value) in json.keyValuePairs() {
  ///   print("\(key): \(value)")
  /// }
  /// ```
  ///
  /// - Returns: An array of `(key, value)` tuples.
  /// - Complexity: O(n) where n is the number of keys — builds a new tuple array.
  public func keyValuePairs() -> [(key: String, value: JSON)] {
    guard case .object(let dict) = storage else { return [] }
    var result: [(key: String, value: JSON)] = []
    result.reserveCapacity(dict.count)
    for (key, value) in dict {
      result.append((key, value))
    }
    return result
  }
}
