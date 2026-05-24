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
    let impl = _JSONEncodeImpl()
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
///
/// This is a reference type that builds a `JSON` value incrementally as
/// encoding containers are created and populated.
final class _JSONEncodeImpl: Encoder {
  /// The final encoded JSON value. Set by the outermost container.
  var json: JSON = .null

  /// The coding path from the root to the current encoding point.
  let codingPath: [CodingKey] = []

  /// User-provided contextual information.
  var userInfo: [CodingUserInfoKey: Any] { _userInfo }

  private let _userInfo: [CodingUserInfoKey: Any]

  init(userInfo: [CodingUserInfoKey: Any] = [:]) {
    self._userInfo = userInfo
  }

  func container<Key: CodingKey>(keyedBy keyType: Key.Type) -> KeyedEncodingContainer<Key> {
    let container = _JSONKeyedEncodingContainer<Key>(encoder: self)
    return KeyedEncodingContainer(container)
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    _JSONUnkeyedEncodingContainer(encoder: self)
  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    _JSONSingleValueEncodingContainer(encoder: self)
  }
}

// MARK: - Keyed encoding container

struct _JSONKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
  let codingPath: [CodingKey] = []

  /// The encoder that owns this container.
  let encoder: _JSONEncodeImpl

  /// The object being built, stored as key-value pairs.
  var object: OrderedDictionary<String, JSON> = [:]

  /// When finished, this becomes the encoder's final json.
  mutating func encode(_ value: JSON, forKey key: Key) throws {
    object[key.stringValue] = value
  }

  mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
    let child = _JSONEncodeImpl(userInfo: encoder.userInfo)
    try value.encode(to: child)
    object[key.stringValue] = child.json
  }

  mutating func encodeNil(forKey key: Key) throws {
    object[key.stringValue] = .null
  }

  mutating func encode(_ value: String, forKey key: Key) throws {
    object[key.stringValue] = .string(value)
  }

  mutating func encode(_ value: Bool, forKey key: Key) throws {
    object[key.stringValue] = .boolean(value)
  }

  mutating func encode(_ value: Int64, forKey key: Key) throws {
    object[key.stringValue] = .number(.integer(value))
  }

  mutating func encode(_ value: Int, forKey key: Key) throws {
    object[key.stringValue] = .number(.integer(Int64(value)))
  }

  mutating func encode(_ value: Double, forKey key: Key) throws {
    object[key.stringValue] = .number(.float(value))
  }

  mutating func encode(_ value: Float, forKey key: Key) throws {
    object[key.stringValue] = .number(.float(Double(value)))
  }

  mutating func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type,
    forKey key: Key
  ) -> KeyedEncodingContainer<NestedKey> {
    let container = _JSONKeyedEncodingContainer<NestedKey>(encoder: encoder)
    object[key.stringValue] = .object(container.object)
    return KeyedEncodingContainer(container)
  }

  mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    let container = _JSONUnkeyedEncodingContainer(encoder: encoder)
    object[key.stringValue] = .array(container.elements)
    return container
  }

  mutating func superEncoder(forKey key: Key) -> Encoder {
    _JSONEncodeImpl(userInfo: encoder.userInfo)
  }

  /// Finishes encoding: sets the encoder's json to the completed object.
  mutating func finish() {
    encoder.json = .object(object)
  }
}

// MARK: - Unkeyed encoding container

struct _JSONUnkeyedEncodingContainer: UnkeyedEncodingContainer {
  let codingPath: [CodingKey] = []
  let encoder: _JSONEncodeImpl

  var elements: [JSON] = []
  var count: Int { elements.count }

  mutating func encode<T: Encodable>(_ value: T) throws {
    let child = _JSONEncodeImpl(userInfo: encoder.userInfo)
    try value.encode(to: child)
    elements.append(child.json)
  }

  mutating func encodeNil() throws {
    elements.append(.null)
  }

  mutating func encode(_ value: String) throws {
    elements.append(.string(value))
  }

  mutating func encode(_ value: Bool) throws {
    elements.append(.boolean(value))
  }

  mutating func encode(_ value: Int64) throws {
    elements.append(.number(.integer(value)))
  }

  mutating func encode(_ value: Int) throws {
    elements.append(.number(.integer(Int64(value))))
  }

  mutating func encode(_ value: Double) throws {
    elements.append(.number(.float(value)))
  }

  mutating func encode(_ value: Float) throws {
    elements.append(.number(.float(Double(value))))
  }

  mutating func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type
  ) -> KeyedEncodingContainer<NestedKey> {
    let container = _JSONKeyedEncodingContainer<NestedKey>(encoder: encoder)
    elements.append(.object(container.object))
    return KeyedEncodingContainer(container)
  }

  mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    let container = _JSONUnkeyedEncodingContainer(encoder: encoder)
    elements.append(.array(container.elements))
    return container
  }

  mutating func superEncoder() -> Encoder {
    _JSONEncodeImpl(userInfo: encoder.userInfo)
  }

  /// Finishes encoding: sets the encoder's json to the completed array.
  mutating func finish() {
    encoder.json = .array(elements)
  }
}

// MARK: - Single-value encoding container

struct _JSONSingleValueEncodingContainer: SingleValueEncodingContainer {
  let codingPath: [CodingKey] = []
  let encoder: _JSONEncodeImpl

  mutating func encodeNil() throws {
    encoder.json = .null
  }

  mutating func encode(_ value: String) throws {
    encoder.json = .string(value)
  }

  mutating func encode(_ value: Bool) throws {
    encoder.json = .boolean(value)
  }

  mutating func encode(_ value: Int64) throws {
    encoder.json = .number(.integer(value))
  }

  mutating func encode(_ value: Int) throws {
    encoder.json = .number(.integer(Int64(value)))
  }

  mutating func encode(_ value: Double) throws {
    encoder.json = .number(.float(value))
  }

  mutating func encode(_ value: Float) throws {
    encoder.json = .number(.float(Double(value)))
  }

  mutating func encode<T: Encodable>(_ value: T) throws {
    let child = _JSONEncodeImpl(userInfo: encoder.userInfo)
    try value.encode(to: child)
    encoder.json = child.json
  }
}
