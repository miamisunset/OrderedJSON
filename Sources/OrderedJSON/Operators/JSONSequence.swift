import Foundation
import OrderedCollections

extension JSON: Sequence {
  /// Iterates over elements. For arrays, yields each element. For objects, yields key-value pairs.
  /// For primitives, yields a single element (self).
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
  public func items() -> [(key: String, value: JSON)] {
    guard case .object(let dict) = storage else { return [] }
    var result: [(key: String, value: JSON)] = []
    result.reserveCapacity(dict.count)
    for (key, value) in dict {
      result.append((key, value))
    }
    return result
  }
}
