import Foundation
import OrderedCollections

extension JSON {
  // MARK: - clear

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

  public mutating func erase(_ key: String) {
    guard case .object(var dict) = storage else { return }
    dict.removeValue(forKey: key)
    storage = .object(dict)
  }

  // MARK: - erase(index)

  public mutating func erase(_ index: Int) {
    guard case .array(var arr) = storage else { return }
    guard index >= 0, index < arr.count else { return }
    arr.remove(at: index)
    storage = .array(arr)
  }

  // MARK: - append (push_back)

  public mutating func append(_ value: JSON) {
    guard case .array(var arr) = storage else { return }
    arr.append(value)
    storage = .array(arr)
  }

  // MARK: - insert at index

  public mutating func insert(_ value: JSON, at index: Int) {
    guard case .array(var arr) = storage else { return }
    guard index >= 0, index <= arr.count else { return }
    arr.insert(value, at: index)
    storage = .array(arr)
  }

  // MARK: - emplace (array)

  public mutating func emplace(_ value: JSON) {
    guard case .array(var arr) = storage else { return }
    arr.append(value)
    storage = .array(arr)
  }

  // MARK: - emplace (object, insert if key absent)

  public mutating func emplace(key: String, default defaultValue: @autoclosure () -> JSON) {
    guard case .object(var dict) = storage else { return }
    if dict[key] == nil {
      dict[key] = defaultValue()
    }
    storage = .object(dict)
  }

  // MARK: - update (merge object keys)

  public mutating func update(with other: JSON) {
    guard case .object(var dict) = storage else { return }
    guard case .object(let otherDict) = other.storage else { return }
    for (key, value) in otherDict {
      dict[key] = value
    }
    storage = .object(dict)
  }

  // MARK: - swap

  public mutating func swap(with other: inout JSON) {
    let temp = self
    self = other
    other = temp
  }
}
