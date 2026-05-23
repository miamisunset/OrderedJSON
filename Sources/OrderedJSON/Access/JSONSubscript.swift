import Foundation
import OrderedCollections

extension JSON {
  // MARK: - Key subscript

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

  public func at(_ key: String) throws -> JSON {
    guard case .object(let dict) = storage else {
      throw JSONError.typeError(expected: "object", actual: typeName)
    }
    guard let value = dict[key] else {
      throw JSONError.keyNotFound(key)
    }
    return value
  }

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

  public func value(_ key: String, default defaultValue: JSON) -> JSON {
    guard case .object(let dict) = storage else { return defaultValue }
    return dict[key] ?? defaultValue
  }
}
