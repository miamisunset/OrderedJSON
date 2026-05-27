import OrderedCollections

/// Represents a JSON numeric value, which can be either an integer or a
/// floating-point number.
///
/// `JSONNumber` is used as the wrapped value inside `JSON.storage.number`.
/// It preserves the original numeric type — integers stay as `Int64` and
/// floats stay as `Double` — without premature stringification.
///
/// ## Example
///
/// ```swift
/// let num = JSONNumber.integer(42)
/// let json = JSON.number(num)
/// ```
public enum JSONNumber: Hashable, Sendable {
    /// An integer value stored as `Int64`.
    case integer(Int64)
    /// A floating-point value stored as `Double`.
    case float(Double)
}
