import Foundation
import OrderedCollections

extension JSON {
  // MARK: - Comparison operators (matching nlohmann/json semantics)

  /// Less-than comparison. For objects/arrays, compares count; for primitives, compares wrapped value.
  public static func < (lhs: JSON, rhs: JSON) -> Bool {
    switch (lhs.storage, rhs.storage) {
    case (.null, .null): return false
    case (.null, _): return true
    case (_, .null): return false
    case (.boolean(let a), .boolean(let b)): return a == false && b == true
    case (.number(.integer(let a)), .number(.integer(let b))): return a < b
    case (.number(.float(let a)), .number(.float(let b))): return a < b
    case (.number(.integer(let a)), .number(.float(let b))): return Double(a) < b
    case (.number(.float(let a)), .number(.integer(let b))): return a < Double(b)
    case (.string(let a), .string(let b)): return a < b
    case (.array(let a), .array(let b)): return a.count < b.count
    case (.object(let a), .object(let b)): return a.count < b.count
    default: return false
    }
  }

  /// Less-than-or-equal comparison.
  public static func <= (lhs: JSON, rhs: JSON) -> Bool {
    lhs < rhs || lhs == rhs
  }

  /// Greater-than comparison.
  public static func > (lhs: JSON, rhs: JSON) -> Bool {
    rhs < lhs
  }

  /// Greater-than-or-equal comparison.
  public static func >= (lhs: JSON, rhs: JSON) -> Bool {
    rhs < lhs || lhs == rhs
  }
}
