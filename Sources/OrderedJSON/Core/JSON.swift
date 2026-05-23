import Foundation
import OrderedCollections

/// The core JSON type — a value type wrapping an internal Storage enum.
/// Mirrors `nlohmann::basic_json` with a rich method-based API.
///
/// `JSON` preserves the order of keys in parsed objects. It uses
/// `OrderedDictionary<String, JSON>` from `swift-collections` instead of
/// the unordered `Dictionary`. This means round-tripping a JSON object
/// through parse/dump retains key ordering.
///
/// ## Creating values
///
/// ```swift
/// let j: JSON = .object([
///   "name": .string("Alice"),
///   "age":  .number(.integer(30))
/// ])
/// ```
///
/// ## Factory methods
///
/// Use `JSON.object(_:)`, `JSON.array(_:)`, `JSON.string(_:)`, etc.
/// Convenience `init` overloads accept `String`, `Bool`, `Int64`, `Int`,
/// `Double`, `[JSON]`, and `OrderedDictionary<String, JSON>`.
///
/// ## Type checks
///
/// `isNull`, `isBoolean`, `isNumber`, `isInteger`, `isFloat`, `isString`,
/// `isObject`, `isArray`, `isPrimitive`, `isStructured`, `type`, `typeName`.
public struct JSON: Hashable, Sendable {

  /// The underlying storage enum.
  internal enum Storage: Hashable, Sendable {
    /// An ordered dictionary mapping string keys to JSON values.
    case object(OrderedDictionary<String, JSON>)
    /// An ordered array of JSON values.
    case array([JSON])
    /// A string value.
    case string(String)
    /// A numeric value (integer or floating-point).
    case number(JSONNumber)
    /// A boolean value.
    case boolean(Bool)
    /// The JSON `null` value.
    case null
  }

  internal var storage: Storage

  private init(storage: Storage) {
    self.storage = storage
  }

  // MARK: - Factory methods

  /// Creates a JSON object value from an ordered dictionary.
  /// - Parameter dict: The ordered dictionary of key-value pairs.
  /// - Returns: A JSON object.
  public static func object(_ dict: OrderedDictionary<String, JSON>) -> JSON {
    JSON(storage: .object(dict))
  }

  /// Creates a JSON array value from an array of JSON values.
  /// - Parameter elements: The array elements.
  /// - Returns: A JSON array.
  public static func array(_ elements: [JSON]) -> JSON {
    JSON(storage: .array(elements))
  }

  /// Creates a JSON string value.
  /// - Parameter value: The string value.
  /// - Returns: A JSON string.
  public static func string(_ value: String) -> JSON {
    JSON(storage: .string(value))
  }

  /// Creates a JSON number value (integer or floating-point).
  /// - Parameter value: The `JSONNumber` value.
  /// - Returns: A JSON number.
  public static func number(_ value: JSONNumber) -> JSON {
    JSON(storage: .number(value))
  }

  /// Creates a JSON boolean value.
  /// - Parameter value: The boolean value.
  /// - Returns: A JSON boolean.
  public static func boolean(_ value: Bool) -> JSON {
    JSON(storage: .boolean(value))
  }

  /// The JSON `null` singleton value.
  /// Equivalent to `JSON.nullValue()`.
  public static let null = JSON(storage: .null)

  /// Creates a JSON null value.
  /// - Returns: A JSON null.
  public static func nullValue() -> JSON {
    JSON(storage: .null)
  }

  // MARK: - Convenience initializers

  public init(_ value: String) { self.storage = .string(value) }
  public init(_ value: Bool) { self.storage = .boolean(value) }
  public init(_ value: Int64) { self.storage = .number(.integer(value)) }
  public init(_ value: Int) { self.storage = .number(.integer(Int64(value))) }
  public init(_ value: Double) { self.storage = .number(.float(value)) }
  public init(_ value: [JSON]) { self.storage = .array(value) }
  public init(_ value: OrderedDictionary<String, JSON>) { self.storage = .object(value) }

  // MARK: - Type checks

  /// Returns `true` if this value is JSON `null`.
  public var isNull: Bool {
    if case .null = storage { return true }
    return false
  }

  /// Returns `true` if this value is a boolean.
  public var isBoolean: Bool {
    if case .boolean = storage { return true }
    return false
  }

  /// Returns `true` if this value is a number (integer or floating-point).
  public var isNumber: Bool {
    if case .number = storage { return true }
    return false
  }

  /// Returns `true` if this value is an integer number.
  public var isInteger: Bool {
    if case .number(.integer) = storage { return true }
    return false
  }

  /// Returns `true` if this value is a floating-point number.
  public var isFloat: Bool {
    if case .number(.float) = storage { return true }
    return false
  }

  /// Returns `true` if this value is a string.
  public var isString: Bool {
    if case .string = storage { return true }
    return false
  }

  /// Returns `true` if this value is an object (ordered dictionary).
  public var isObject: Bool {
    if case .object = storage { return true }
    return false
  }

  /// Returns `true` if this value is an array.
  public var isArray: Bool {
    if case .array = storage { return true }
    return false
  }

  /// Returns `true` if this value is a primitive (null, boolean, number, or string).
  /// Primitives are leaf values with no child elements.
  public var isPrimitive: Bool {
    switch storage {
    case .null, .boolean, .number, .string: return true
    case .object, .array: return false
    }
  }

  /// Returns `true` if this value is a structured type (object or array).
  /// Structured types can contain child elements.
  public var isStructured: Bool {
    switch storage {
    case .object, .array: return true
    case .null, .boolean, .number, .string: return false
    }
  }

  /// Enum representing the JSON type of a value.
  public enum JSONType: Hashable, Sendable {
    case null
    case boolean
    case number
    case string
    case object
    case array
  }

  /// Returns the JSON type of this value as a `JSONType` enum case.
  public var type: JSONType {
    switch storage {
    case .null: return .null
    case .boolean: return .boolean
    case .number: return .number
    case .string: return .string
    case .object: return .object
    case .array: return .array
    }
  }

  /// Returns a human-readable name for the JSON type of this value.
  /// One of: `"null"`, `"boolean"`, `"number"`, `"string"`, `"object"`, `"array"`.
  public var typeName: String {
    switch type {
    case .null: return "null"
    case .boolean: return "boolean"
    case .number: return "number"
    case .string: return "string"
    case .object: return "object"
    case .array: return "array"
    }
  }

  // MARK: - Value accessors

  /// Returns the string value if this JSON value is a string, otherwise nil.
  public var stringValue: String? {
    guard case .string(let s) = storage else { return nil }
    return s
  }
}

// MARK: - Hashable conformance

extension JSON {
  public func hash(into hasher: inout Hasher) {
    switch storage {
    case .null:
      hasher.combine(0)
    case .boolean(let v):
      hasher.combine(1)
      hasher.combine(v)
    case .number(let v):
      hasher.combine(2)
      hasher.combine(v)
    case .string(let v):
      hasher.combine(3)
      hasher.combine(v)
    case .array(let v):
      hasher.combine(4)
      hasher.combine(v)
    case .object(let v):
      hasher.combine(5)
      hasher.combine(v)
    }
  }
}

extension JSON {
  /// Equality comparison. Two JSON values are equal if they have the same
  /// storage case and the same wrapped value.
  public static func == (lhs: JSON, rhs: JSON) -> Bool {
    switch (lhs.storage, rhs.storage) {
    case (.null, .null): return true
    case (.boolean(let a), .boolean(let b)): return a == b
    case (.number(let a), .number(let b)): return a == b
    case (.string(let a), .string(let b)): return a == b
    case (.array(let a), .array(let b)): return a == b
    case (.object(let a), .object(let b)): return a == b
    default: return false
    }
  }
}
