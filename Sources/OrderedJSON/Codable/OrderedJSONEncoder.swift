import OrderedCollections

/// A JSON encoder that produces `JSON` values with preserved key order.
///
/// Unlike `JSONEncoder` from Foundation, `OrderedJSONEncoder` encodes into
/// the `JSON` type directly, maintaining the order of keys in objects.
/// This is useful when you need to encode a `Codable` struct into a `JSON`
/// value for further manipulation (e.g., merging, patching).
///
/// ## Example
///
/// ```swift
/// struct Person: Codable {
///   let name: String
///   let age: Int
/// }
///
/// let encoder = OrderedJSONEncoder()
/// let json = try encoder.encode(Person(name: "Alice", age: 30))
/// // json is a JSON object with keys in declaration order: ["name", "age"]
/// ```
public struct OrderedJSONEncoder {
  /// Any user-provided contextual information.
  public var userInfo: [CodingUserInfoKey: Any]

  public init() {
    self.userInfo = [:]
  }

  /// Encodes a `Codable` value into a `JSON` value, preserving key order.
  ///
  /// - Parameter value: The value to encode.
  /// - Returns: A `JSON` value.
  /// - Throws: Encoding errors from the value's `encode(to:)` implementation.
  public func encode<T: Encodable>(_ value: T) throws -> JSON {
    let impl = _JSONEncodeImpl(userInfo: userInfo)
    try value.encode(to: impl)
    return impl.json
  }

  /// Encodes a `Codable` value into a JSON string, preserving key order.
  ///
  /// - Parameter value: The value to encode.
  /// - Returns: A compact JSON string.
  /// - Throws: Encoding errors from the value's `encode(to:)` implementation.
  public func encodeToString<T: Encodable>(_ value: T) throws -> String {
    let json = try encode(value)
    return json.dump(indent: -1)
  }
}

// MARK: - Internal encoder implementation

/// The concrete `Encoder` implementation used by `OrderedJSONEncoder`.
final class _JSONEncodeImpl: Encoder {
  /// The final encoded JSON value.
  var json: JSON = .null

  let codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any]

  init(userInfo: [CodingUserInfoKey: Any] = [:]) {
    self.userInfo = userInfo
  }

  func container<Key: CodingKey>(keyedBy keyType: Key.Type) -> KeyedEncodingContainer<Key> {
    let container = _JSONKeyedEncodingContainer<Key>(impl: self)
    return KeyedEncodingContainer(container)
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    _JSONUnkeyedEncodingContainer(impl: self)
  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    _JSONSingleValueEncodingContainer(impl: self)
  }
}

// MARK: - Keyed encoding container (class-based)

/// A class-based keyed encoding container so nested containers share state.
final class _JSONKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
  let codingPath: [CodingKey] = []
  let impl: _JSONEncodeImpl
  var object: OrderedDictionary<String, JSON> = [:]

  init(impl: _JSONEncodeImpl) {
    self.impl = impl
  }

  func encode(_ value: JSON, forKey key: Key) throws {
    object[key.stringValue] = value
  }

  func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
    let child = _JSONEncodeImpl(userInfo: impl.userInfo)
    try value.encode(to: child)
    object[key.stringValue] = child.json
  }

  func encodeNil(forKey key: Key) throws {
    object[key.stringValue] = .null
  }

  func encode(_ value: String, forKey key: Key) throws {
    object[key.stringValue] = .string(value)
  }

  func encode(_ value: Bool, forKey key: Key) throws {
    object[key.stringValue] = .boolean(value)
  }

  func encode(_ value: Int64, forKey key: Key) throws {
    object[key.stringValue] = .number(.integer(value))
  }

  func encode(_ value: Int, forKey key: Key) throws {
    object[key.stringValue] = .number(.integer(Int64(value)))
  }

  func encode(_ value: Double, forKey key: Key) throws {
    object[key.stringValue] = .number(.float(value))
  }

  func encode(_ value: Float, forKey key: Key) throws {
    object[key.stringValue] = .number(.float(Double(value)))
  }

  func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type,
    forKey key: Key
  ) -> KeyedEncodingContainer<NestedKey> {
    let child = _JSONKeyedEncodingContainer<NestedKey>(impl: impl)
    object[key.stringValue] = .object(child.object)
    return KeyedEncodingContainer(child)
  }

  func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    let child = _JSONUnkeyedEncodingContainer(impl: impl)
    object[key.stringValue] = .array(child.elements)
    return child
  }

  func superEncoder(forKey key: Key) -> Encoder {
    _JSONEncodeImpl(userInfo: impl.userInfo)
  }

  func superEncoder() -> Encoder {
    _JSONEncodeImpl(userInfo: impl.userInfo)
  }

  func finish() {
    impl.json = .object(object)
  }
}

// MARK: - Unkeyed encoding container (class-based)

final class _JSONUnkeyedEncodingContainer: UnkeyedEncodingContainer {
  let codingPath: [CodingKey] = []
  let impl: _JSONEncodeImpl
  var elements: [JSON] = []
  var count: Int { elements.count }

  init(impl: _JSONEncodeImpl) {
    self.impl = impl
  }

  func encode<T: Encodable>(_ value: T) throws {
    let child = _JSONEncodeImpl(userInfo: impl.userInfo)
    try value.encode(to: child)
    elements.append(child.json)
  }

  func encodeNil() throws {
    elements.append(.null)
  }

  func encode(_ value: String) throws {
    elements.append(.string(value))
  }

  func encode(_ value: Bool) throws {
    elements.append(.boolean(value))
  }

  func encode(_ value: Int64) throws {
    elements.append(.number(.integer(value)))
  }

  func encode(_ value: Int) throws {
    elements.append(.number(.integer(Int64(value))))
  }

  func encode(_ value: Double) throws {
    elements.append(.number(.float(value)))
  }

  func encode(_ value: Float) throws {
    elements.append(.number(.float(Double(value))))
  }

  func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type
  ) -> KeyedEncodingContainer<NestedKey> {
    let child = _JSONKeyedEncodingContainer<NestedKey>(impl: impl)
    elements.append(.object(child.object))
    return KeyedEncodingContainer(child)
  }

  func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    let child = _JSONUnkeyedEncodingContainer(impl: impl)
    elements.append(.array(child.elements))
    return child
  }

  func superEncoder() -> Encoder {
    _JSONEncodeImpl(userInfo: impl.userInfo)
  }

  func finish() {
    impl.json = .array(elements)
  }
}

// MARK: - Single-value encoding container (struct is fine)

struct _JSONSingleValueEncodingContainer: SingleValueEncodingContainer {
  let codingPath: [CodingKey] = []
  let impl: _JSONEncodeImpl

  init(impl: _JSONEncodeImpl) {
    self.impl = impl
  }

  mutating func encodeNil() throws {
    impl.json = .null
  }

  mutating func encode(_ value: String) throws {
    impl.json = .string(value)
  }

  mutating func encode(_ value: Bool) throws {
    impl.json = .boolean(value)
  }

  mutating func encode(_ value: Int64) throws {
    impl.json = .number(.integer(value))
  }

  mutating func encode(_ value: Int) throws {
    impl.json = .number(.integer(Int64(value)))
  }

  mutating func encode(_ value: Double) throws {
    impl.json = .number(.float(value))
  }

  mutating func encode(_ value: Float) throws {
    impl.json = .number(.float(Double(value)))
  }

  mutating func encode<T: Encodable>(_ value: T) throws {
    let child = _JSONEncodeImpl(userInfo: impl.userInfo)
    try value.encode(to: child)
    impl.json = child.json
  }
}
