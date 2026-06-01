import Foundation
import OrderedCollections

// Comparable conformance is declared on JSON itself — the operators below
// satisfy Comparable's requirements (a < a is false, a < b implies !(b < a)).
// Cross-type comparisons use the nlohmann/json type hierarchy:
// null < boolean < number < object < array < string < binary

extension JSON {
  // MARK: - Type ordering (matching nlohmann/json semantics)

  /// Maps a `Storage` case to its comparison ordinal.
  ///
  /// nlohmann/json ordering:
  /// null(0) < boolean(1) < number(2) < object(3) < array(4) < string(5) < binary(6)
  private static func typeOrder(_ storage: Storage) -> Int {
    switch storage {
    case .null: return 0
    case .boolean: return 1
    case .number: return 2
    case .object: return 3
    case .array: return 4
    case .string: return 5
    }
  }

  // MARK: - Comparison operators (matching nlohmann/json semantics)

  /// Less-than comparison.
  ///
  /// Matches nlohmann/json semantics:
  /// - Null is less than any non-null value.
  /// - Booleans: `false < true`.
  /// - Numbers are compared numerically with integer-to-float promotion.
  /// - Strings are compared lexicographically.
  /// - Arrays and objects are compared by count (shorter is smaller).
  /// - Different types compare by type hierarchy:
  ///   `null < boolean < number < object < array < string`
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side JSON value.
  ///   - rhs: The right-hand side JSON value.
  /// - Returns: `true` if `lhs` is less than `rhs`.
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
    default:
      return typeOrder(lhs.storage) < typeOrder(rhs.storage)
    }
  }

  /// Less-than-or-equal comparison.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side JSON value.
  ///   - rhs: The right-hand side JSON value.
  /// - Returns: `true` if `lhs <= rhs`.
  public static func <= (lhs: JSON, rhs: JSON) -> Bool {
    lhs < rhs || lhs == rhs
  }

  /// Greater-than comparison.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side JSON value.
  ///   - rhs: The right-hand side JSON value.
  /// - Returns: `true` if `lhs > rhs`.
  public static func > (lhs: JSON, rhs: JSON) -> Bool {
    rhs < lhs
  }

  /// Greater-than-or-equal comparison.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side JSON value.
  ///   - rhs: The right-hand side JSON value.
  /// - Returns: `true` if `lhs >= rhs`.
  public static func >= (lhs: JSON, rhs: JSON) -> Bool {
    rhs < lhs || lhs == rhs
  }
}
