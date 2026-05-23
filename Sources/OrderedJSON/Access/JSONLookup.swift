import Foundation
import OrderedCollections

extension JSON {
  // MARK: - contains

  public func contains(_ key: String) -> Bool {
    guard case .object(let dict) = storage else { return false }
    return dict.keys.contains(key)
  }

  // MARK: - count(_ key:)

  public func count(_ key: String) -> Int {
    guard case .object(let dict) = storage else { return 0 }
    return dict.keys.contains(key) ? 1 : 0
  }

  // MARK: - find

  public func find(_ key: String) -> JSON? {
    guard case .object(let dict) = storage else { return nil }
    return dict[key]
  }
}
