import Foundation
import OrderedCollections

public extension JSON {
    // MARK: - Comparison operators (matching nlohmann/json semantics)

    /// Less-than comparison.
    ///
    /// Matches nlohmann/json semantics:
    /// - Null is less than any non-null value.
    /// - Booleans: `false < true`.
    /// - Numbers are compared numerically with integer-to-float promotion.
    /// - Strings are compared lexicographically.
    /// - Arrays and objects are compared by count (shorter is smaller).
    /// - Different types are not comparable (returns `false`).
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side JSON value.
    ///   - rhs: The right-hand side JSON value.
    /// - Returns: `true` if `lhs` is less than `rhs`.
    static func < (lhs: JSON, rhs: JSON) -> Bool {
        switch (lhs.storage, rhs.storage) {
        case (.null, .null): return false
        case (.null, _): return true
        case (_, .null): return false
        case let (.boolean(a), .boolean(b)): return a == false && b == true
        case let (.number(.integer(a)), .number(.integer(b))): return a < b
        case let (.number(.float(a)), .number(.float(b))): return a < b
        case let (.number(.integer(a)), .number(.float(b))): return Double(a) < b
        case let (.number(.float(a)), .number(.integer(b))): return a < Double(b)
        case let (.string(a), .string(b)): return a < b
        case let (.array(a), .array(b)): return a.count < b.count
        case let (.object(a), .object(b)): return a.count < b.count
        default: return false
        }
    }

    /// Less-than-or-equal comparison.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side JSON value.
    ///   - rhs: The right-hand side JSON value.
    /// - Returns: `true` if `lhs <= rhs`.
    static func <= (lhs: JSON, rhs: JSON) -> Bool {
        lhs < rhs || lhs == rhs
    }

    /// Greater-than comparison.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side JSON value.
    ///   - rhs: The right-hand side JSON value.
    /// - Returns: `true` if `lhs > rhs`.
    static func > (lhs: JSON, rhs: JSON) -> Bool {
        rhs < lhs
    }

    /// Greater-than-or-equal comparison.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side JSON value.
    ///   - rhs: The right-hand side JSON value.
    /// - Returns: `true` if `lhs >= rhs`.
    static func >= (lhs: JSON, rhs: JSON) -> Bool {
        rhs < lhs || lhs == rhs
    }
}
