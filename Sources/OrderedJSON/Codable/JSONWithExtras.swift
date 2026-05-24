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

  /// Creates a `JSONWithExtras` with explicit value and extras.
  public init(value: T, extras: JSON) {
    self.value = value
    self.extras = extras
  }

  /// Creates a `JSONWithExtras` by decoding known keys into `T` and
  /// capturing unknown keys into `extras`.
  ///
  /// Uses a tracking decoder that records which keys `T` accesses,
  /// then treats unaccessed keys as extras.
  public init(from decoder: Decoder) throws {
    // Step 1: Decode all values as JSON
    let allValues = try decoder.container(keyedBy: _ExtrasKey.self)
    let keys = allValues.allKeys
    var dict = OrderedDictionary<String, JSON>()
    for key in keys {
      dict[key.stringValue] = try allValues.decode(JSON.self, forKey: key)
    }
    let jsonObject = JSON.object(dict)

    // Step 2: Decode T while tracking which keys it accesses
    var usedKeys = Set<String>()
    let trackingDecoder = _TrackingDecoder(
      json: jsonObject,
      onAccess: { usedKeys.insert($0) })
    value = try T(from: trackingDecoder)

    // Step 3: Remaining keys are extras
    var extrasDict = OrderedDictionary<String, JSON>()
    for (key, value) in dict where !usedKeys.contains(key) {
      extrasDict[key] = value
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

/// A decoder that tracks which keys were accessed during decoding.
private struct _TrackingDecoder: Decoder {
  let json: JSON
  let onAccess: (String) -> Void
  let codingPath: [CodingKey] = []
  let userInfo: [CodingUserInfoKey: Any] = [:]

  func container<Key: CodingKey>(keyedBy keyType: Key.Type) throws -> KeyedDecodingContainer<Key> {
    let tracking = _TrackingKeyedDecodingContainer<Key>(
      json: json, onAccess: onAccess)
    return KeyedDecodingContainer(tracking)
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

/// A keyed decoding container that records which keys were accessed.
private struct _TrackingKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
  let json: JSON
  let onAccess: (String) -> Void
  let codingPath: [CodingKey] = []

  var allKeys: [Key] {
    guard case .object(let dict) = json.storage else { return [] }
    return dict.keys.compactMap {
      Key(stringValue: $0)
    }
  }

  func contains(_ key: Key) -> Bool {
    guard case .object(let dict) = json.storage else { return false }
    return dict.keys.contains(key.stringValue)
  }

  func decodeNil(forKey key: Key) throws -> Bool {
    onAccess(key.stringValue)
    guard case .object(let dict) = json.storage else { return true }
    guard let val = dict[key.stringValue] else { return true }
    return val == .null
  }

  func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    onAccess(key.stringValue)
    return try json[key.stringValue]!.requireBool()
  }

  func decode(_ type: String.Type, forKey key: Key) throws -> String {
    onAccess(key.stringValue)
    return try json[key.stringValue]!.requireString()
  }

  func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    onAccess(key.stringValue)
    return try json[key.stringValue]!.requireInt64()
  }

  func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    onAccess(key.stringValue)
    return try json[key.stringValue]!.requireInt()
  }

  func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    onAccess(key.stringValue)
    return try json[key.stringValue]!.requireDouble()
  }

  func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    onAccess(key.stringValue)
    return try json[key.stringValue]!.requireFloat()
  }

  func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
    onAccess(key.stringValue)
    let val = json[key.stringValue]!
    let decoder = OrderedJSONDecoder()
    return try decoder.decode(type, from: val)
  }

  func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type, forKey key: Key
  ) throws -> KeyedDecodingContainer<NestedKey> {
    onAccess(key.stringValue)
    let val = json[key.stringValue]!
    let tracking = _TrackingKeyedDecodingContainer<NestedKey>(
      json: val, onAccess: onAccess)
    return KeyedDecodingContainer(tracking)
  }

  func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    onAccess(key.stringValue)
    let val = json[key.stringValue]!
    guard case .array(let elements) = val.storage else {
      throw DecodingError.typeMismatch(
        JSON.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected an array"))
    }
    return _JSONUnkeyedDecodingContainer(
      elements: elements, encoder: _JSONDecodeImpl(json: val, userInfo: [:]))
  }

  func superDecoder(forKey key: Key) throws -> Decoder {
    onAccess(key.stringValue)
    let val = json[key.stringValue]!
    return _TrackingDecoder(json: val, onAccess: onAccess)
  }

  func superDecoder() throws -> Decoder {
    _TrackingDecoder(json: json, onAccess: onAccess)
  }
}

/// An encoder wrapper that only encodes known keys (used for encoding `T`).
private struct _ValueEncoder: Encoder {
  let container: KeyedEncodingContainer<_ExtrasKey>
  let codingPath: [CodingKey] = []
  let userInfo: [CodingUserInfoKey: Any] = [:]

  func container<Key: CodingKey>(keyedBy keyType: Key.Type) -> KeyedEncodingContainer<Key> {
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

/// A keyed encoding container that writes to the parent container.
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
    container.nestedContainer(
      keyedBy: keyType, forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    container.nestedUnkeyedContainer(forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func superEncoder(forKey key: Key) -> Encoder {
    container.superEncoder(forKey: _ExtrasKey(stringValue: key.stringValue))
  }

  mutating func superEncoder() -> Encoder {
    container.superEncoder()
  }
}
