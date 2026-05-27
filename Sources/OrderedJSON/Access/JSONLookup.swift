import Foundation
import OrderedCollections

public extension JSON {
    // MARK: - contains

    /// Returns `true` if a JSON object contains the given key.
    ///
    /// For non-object values, always returns `false`.
    /// - Parameter key: The key to look up.
    /// - Returns: `true` if the key exists in this object.
    func contains(_ key: String) -> Bool {
        guard case let .object(dict) = storage else { return false }
        return dict.keys.contains(key)
    }

    /// Returns `true` if a JSON array contains the given element.
    ///
    /// Uses `==` for comparison. For non-array values, always returns `false`.
    ///
    /// - Note: Because `JSON` conforms to `ExpressibleByStringLiteral`, passing a raw
    ///   string `"foo"` hits the `String` overload (object key lookup). Use
    ///   `.string("foo")` explicitly for array element containment.
    ///
    /// - Parameter element: The element to look up.
    /// - Returns: `true` if the element exists in this array.
    func contains(_ element: JSON) -> Bool {
        guard case let .array(arr) = storage else { return false }
        return arr.contains(element)
    }

    // MARK: - count(_ key:)

    /// Returns 1 if a JSON object contains the given key, or 0 otherwise.
    ///
    /// This matches nlohmann/json semantics where `count(key)` returns
    /// 1 if the key exists (since JSON objects can't have duplicate keys).
    /// For non-object values, always returns 0.
    /// - Parameter key: The key to check.
    /// - Returns: 1 if the key exists, 0 otherwise.
    func count(_ key: String) -> Int {
        guard case let .object(dict) = storage else { return 0 }
        return dict.keys.contains(key) ? 1 : 0
    }

    // MARK: - find

    /// Finds a value by key in a JSON object.
    ///
    /// Returns `nil` if the key doesn't exist or if the value is not an object.
    /// - Parameter key: The key to look up.
    /// - Returns: The value for the key, or `nil`.
    func find(_ key: String) -> JSON? {
        guard case let .object(dict) = storage else { return nil }
        return dict[key]
    }
}
