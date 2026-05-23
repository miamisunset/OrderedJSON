import Foundation
import OrderedCollections

extension JSON {
  // MARK: - Capacity

  public var count: Int {
    switch storage {
    case .object(let dict): return dict.count
    case .array(let arr): return arr.count
    case .null, .boolean, .number, .string: return 0
    }
  }

  public var isEmpty: Bool {
    switch storage {
    case .object(let dict): return dict.isEmpty
    case .array(let arr): return arr.isEmpty
    case .null: return true
    case .boolean, .number, .string: return false
    }
  }

  public var maxCount: Int {
    Int.max
  }

  // MARK: - First / Last

  public var first: JSON? {
    switch storage {
    case .array(let arr): return arr.first
    case .object(let dict):
      guard let firstKey = dict.keys.first else { return nil }
      return dict[firstKey]
    case .null, .boolean, .number, .string: return nil
    }
  }

  public var last: JSON? {
    switch storage {
    case .array(let arr): return arr.last
    case .object(let dict):
      guard let lastKey = dict.keys.last else { return nil }
      return dict[lastKey]
    case .null, .boolean, .number, .string: return nil
    }
  }
}
