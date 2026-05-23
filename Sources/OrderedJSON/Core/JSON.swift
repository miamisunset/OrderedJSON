import Foundation
import OrderedCollections

/// The core JSON type — a value type wrapping an internal Storage enum.
/// Mirrors `nlohmann::basic_json` with a rich method-based API.
public struct JSON: Hashable, Sendable {
  internal enum Storage: Hashable, Sendable {
    case object(OrderedDictionary<String, JSON>)
    case array([JSON])
    case string(String)
    case number(JSONNumber)
    case boolean(Bool)
    case null
  }

  internal var storage: Storage

  private init(storage: Storage) {
    self.storage = storage
  }

  // MARK: - Factory methods

  public static func object(_ dict: OrderedDictionary<String, JSON>) -> JSON {
    JSON(storage: .object(dict))
  }

  public static func array(_ elements: [JSON]) -> JSON {
    JSON(storage: .array(elements))
  }

  public static func string(_ value: String) -> JSON {
    JSON(storage: .string(value))
  }

  public static func number(_ value: JSONNumber) -> JSON {
    JSON(storage: .number(value))
  }

  public static func boolean(_ value: Bool) -> JSON {
    JSON(storage: .boolean(value))
  }

  public static let null = JSON(storage: .null)

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

  public var isNull: Bool {
    if case .null = storage { return true }
    return false
  }

  public var isBoolean: Bool {
    if case .boolean = storage { return true }
    return false
  }

  public var isNumber: Bool {
    if case .number = storage { return true }
    return false
  }

  public var isInteger: Bool {
    if case .number(.integer) = storage { return true }
    return false
  }

  public var isFloat: Bool {
    if case .number(.float) = storage { return true }
    return false
  }

  public var isString: Bool {
    if case .string = storage { return true }
    return false
  }

  public var isObject: Bool {
    if case .object = storage { return true }
    return false
  }

  public var isArray: Bool {
    if case .array = storage { return true }
    return false
  }

  public var isPrimitive: Bool {
    switch storage {
    case .null, .boolean, .number, .string: return true
    case .object, .array: return false
    }
  }

  public var isStructured: Bool {
    switch storage {
    case .object, .array: return true
    case .null, .boolean, .number, .string: return false
    }
  }

  public enum JSONType: Hashable, Sendable {
    case null
    case boolean
    case number
    case string
    case object
    case array
  }

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

// MARK: - Backward compatibility typealias

public typealias JSONValue = JSON
