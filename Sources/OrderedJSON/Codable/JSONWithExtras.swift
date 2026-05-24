import OrderedCollections

/// A wrapper that captures unknown JSON keys as extras during decoding.
///
/// `JSONWithExtras` is useful when you want to decode a known set of fields
/// into a strongly-typed struct while preserving any additional keys as a
/// `JSON` object. This is similar to `#[serde(flatten)]` with
/// `#[serde(skip_serializing_if = "Option::is_none")]` from serde.
///
/// ## Example
///
/// ```swift
/// struct Person: Codable {
///   let name: String
///   let age: Int
/// }
///
/// let data = Data(#"""
///   {"name": "Alice", "age": 30, "color": "blue", "city": "NYC"}
///   """#.utf8)
///
/// let wrapped = try OrderedJSONDecoder().decode(
///   JSONWithExtras<Person>.self, from: data)
/// // wrapped.value.name == "Alice"
/// // wrapped.value.age == 30
/// // wrapped.extras["color"] == "blue"
/// // wrapped.extras["city"] == "NYC"
/// ```
public struct JSONWithExtras<T: Decodable>: Decodable {
  /// The decoded value of known fields.
  public let value: T

  /// Any unknown keys not part of `T`, captured as a JSON object.
  public let extras: JSON

  /// Creates a `JSONWithExtras` by decoding known keys into `T` and
  /// capturing unknown keys into `extras`.
  ///
  /// This initializer uses the `OrderedJSONDecoder` internally to
  /// preserve key order for the extras object.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: _ExtrasKey.self)
    let allKeys = container.allKeys
    let knownKeys = Set(allKeys.map { $0.stringValue })

    // Decode the known struct fields
    let valueDecoder = _ValueDecoder(container: container, knownKeys: knownKeys)
    value = try T(from: valueDecoder)

    // Collect unknown keys into extras
    var extrasDict = OrderedDictionary<String, JSON>()
    for key in allKeys where !knownKeys.contains(key.stringValue) {
      let json = try container.decode(JSON.self, forKey: key)
      extrasDict[key.stringValue] = json
    }
    extras = .object(extrasDict)
  }
}

extension JSONWithExtras: Encodable where T: Encodable {
  /// Encodes both the known fields and extras into a single JSON object.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: _ExtrasKey.self)

    // Encode known fields
    try value.encode(to: _ValueEncoder(container: container))

    // Encode extras
    guard case .object(let extrasDict) = extras.storage else { return }
    for (key, value) in extrasDict {
      try container.encode(value, forKey: _ExtrasKey(stringValue: key))
    }
  }
}

// MARK: - Internal helpers

/// A `CodingKey` used for extras — maps any string key.
private struct _ExtrasKey: CodingKey {
  let stringValue: String
  let intValue: Int?
  init(stringValue: String) {
    self.stringValue = stringValue
    self.intValue = nil
  }
  init(intValue: Int) {
    self.stringValue = "\(intValue)"
    self.intValue = intValue
  }
}

/// A decoder wrapper that hides unknown keys from the child decoder.
/// This ensures `T` only sees its own keys and doesn't fail on extras.
private struct _ValueDecoder: Decoder {
  let container: KeyedDecodingContainer<_ExtrasKey>
  let knownKeys: Set<String>
  let codingPath: [CodingKey] = []
  let userInfo: [CodingUserInfoKey: Any] = [:]

  func container<Key: CodingKey>(keyedBy keyType: Key.Type) throws -> KeyedDecodingContainer<Key> {
    let filtered = _FilteredKeyedDecodingContainer<Key>(
      container: container, knownKeys: knownKeys)
    return KeyedDecodingContainer(filtered)
  }

  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    throw DecodingError.typeMismatch(
      JSON.self,
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription: "Expected a JSON object for extras wrapper"))
  }

  func singleValueContainer() throws -> SingleValueDecodingContainer {
    throw DecodingError.typeMismatch(
      JSON.self,
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription: "Expected a JSON object for extras wrapper"))
  }
}

/// A keyed decoding container that only exposes keys in `knownKeys`.
private struct _FilteredKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
  var container: KeyedDecodingContainer<_ExtrasKey>
  let knownKeys: Set<String>
  let codingPath: [CodingKey] = []
  var allKeys: [Key] { [] }  // Not needed — we use the parent container

  func contains(_ key: Key) -> Bool { knownKeys.contains(key.stringValue) }

  func decodeNil(forKey key: Key) throws -> Bool {
    try container.decodeNil(forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    try container.decode(type, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  func decode(_ type: String.Type, forKey key: Key) throws -> String {
    try container.decode(type, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    try container.decode(type, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    try container.decode(type, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    try container.decode(type, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    try container.decode(type, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
    try container.decode(type, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type, forKey key: Key
  ) throws -> KeyedDecodingContainer<NestedKey> {
    try container.nestedContainer(
      keyedBy: keyType, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    try container.nestedUnkeyedContainer(forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  func superDecoder(forKey key: Key) throws -> Decoder {
    try container.superDecoder(forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  func superDecoder() throws -> Decoder {
    // Fallback: use the parent container's super decoder.
    // This is rarely used in practice for extras wrappers.
    try container.superDecoder()
  }
}

/// An encoder wrapper that only encodes known keys (used for encoding `T`).
private struct _ValueEncoder: Encoder {
  let container: KeyedEncodingContainer<_ExtrasKey>
  let codingPath: [CodingKey] = []
  let userInfo: [CodingUserInfoKey: Any] = [:]

  func container<Key: CodingKey>(keyedBy keyType: Key.Type) -> KeyedEncodingContainer<Key> {
    // Return a proxy that wraps the parent container
    let proxy = _FilteredKeyedEncodingContainer<Key>(container: container)
    return KeyedEncodingContainer(proxy)
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    fatalError("Not supported for extras wrapper encoding")
  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    fatalError("Not supported for extras wrapper encoding")
  }
}

/// An keyed encoding container that writes to the parent container.
private struct _FilteredKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
  var container: KeyedEncodingContainer<_ExtrasKey>
  let codingPath: [CodingKey] = []

  mutating func encodeNil(forKey key: Key) throws {
    try container.encodeNil(forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func encode(_ value: Bool, forKey key: Key) throws {
    try container.encode(value, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func encode(_ value: String, forKey key: Key) throws {
    try container.encode(value, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func encode(_ value: Int64, forKey key: Key) throws {
    try container.encode(value, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func encode(_ value: Int, forKey key: Key) throws {
    try container.encode(value, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func encode(_ value: Double, forKey key: Key) throws {
    try container.encode(value, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func encode(_ value: Float, forKey key: Key) throws {
    try container.encode(value, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
    try container.encode(value, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type, forKey key: Key
  ) -> KeyedEncodingContainer<NestedKey> {
    try! container.nestedContainer(
      keyedBy: keyType, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    try! container.nestedUnkeyedContainer(forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func superEncoder(forKey key: Key) -> Encoder {
    try! container.superEncoder(forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func superEncoder() -> Encoder {
    try! container.superEncoder()
  }
}
