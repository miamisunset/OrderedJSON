import OrderedCollections

/// A wrapper that captures unknown JSON keys as extras during decoding.
///
/// `JSONWithExtras` is useful when you want to decode a known set of fields
/// into a strongly-typed struct while preserving any additional keys as a
/// `JSON` object.
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
///
/// ## Known Limitations
///
/// - **Tracking granularity**: All key access methods (`decode(...)`,
///   `decodeNil(forKey:)`, and `contains(_:)`) mark keys as "accessed".
///   This prevents `decodeIfPresent` probes from leaking into extras.
///   Use `decodeIfPresent` for optional fields rather than `contains` + `decodeNil`.
/// - **Optional fields**: `decodeNil(forKey:)` marks the key as accessed even
///   when the key is absent in JSON. This means an absent optional field is
///   correctly excluded from extras.
/// - **Keyed-object only**: `T` must encode/decode as a keyed object.
///   Single-value and unkeyed containers are not supported.
/// - **Extras must be a JSON object**: When encoding, `extras` must be a JSON
///   object; encoding non-object extras throws `EncodingError.invalidValue`.
/// - **Set `userInfo` before calling**: The encoder/decoder copies `userInfo`
///   at construction time; mutations after calling `encode`/`decode` do not
///   propagate to nested containers.
public struct JSONWithExtras<T: Decodable>: Decodable {
  /// The decoded value of known fields.
  public let value: T

  /// Any unknown keys not part of `T`, captured as a JSON object.
  public let extras: JSON

  public init(value: T, extras: JSON) {
    self.value = value
    self.extras = extras
  }

  /// Decodes known keys into `T` and captures unknown keys into `extras`.
  ///
  /// Uses a tracking decoder that records which keys `T` accesses,
  /// then treats unaccessed keys as extras.
  public init(from decoder: Decoder) throws {
    // Extract strategies from the outer decoder if it's our impl
    var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
    var dataDecodingStrategy: DataDecodingStrategy = .base64
    var decimalDecodingStrategy: DecimalDecodingStrategy = .asString
    if let impl = decoder as? _JSONDecodeImpl {
      dateDecodingStrategy = impl.dateDecodingStrategy
      dataDecodingStrategy = impl.dataDecodingStrategy
      decimalDecodingStrategy = impl.decimalDecodingStrategy
    }

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
      onAccess: { usedKeys.insert($0) },
      codingPath: decoder.codingPath,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy)
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

    // Encode extras — must be a JSON object
    guard case .object(let extrasDict) = extras.storage else {
      throw EncodingError.invalidValue(
        extras,
        EncodingError.Context(
          codingPath: encoder.codingPath,
          debugDescription: "Extras must be a JSON object, got \(extras.typeName)"))
    }
    for (key, value) in extrasDict {
      try container.encode(value, forKey: _ExtrasKey(stringValue: key))
    }
  }
}

// MARK: - Internal helpers

/// A `CodingKey` that maps any string key.
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
  let codingPath: [CodingKey]
  let userInfo: [CodingUserInfoKey: Any] = [:]
  let dateDecodingStrategy: DateDecodingStrategy
  let dataDecodingStrategy: DataDecodingStrategy
  let decimalDecodingStrategy: DecimalDecodingStrategy

  init(
    json: JSON,
    onAccess: @escaping (String) -> Void,
    codingPath: [CodingKey] = [],
    dateDecodingStrategy: DateDecodingStrategy = .deferredToDate,
    dataDecodingStrategy: DataDecodingStrategy = .base64,
    decimalDecodingStrategy: DecimalDecodingStrategy = .asString
  ) {
    self.json = json
    self.onAccess = onAccess
    self.codingPath = codingPath
    self.dateDecodingStrategy = dateDecodingStrategy
    self.dataDecodingStrategy = dataDecodingStrategy
    self.decimalDecodingStrategy = decimalDecodingStrategy
  }

  func container<Key: CodingKey>(keyedBy keyType: Key.Type) throws -> KeyedDecodingContainer<Key> {
    return KeyedDecodingContainer(
      _TrackingKeyedDecodingContainer<Key>(
        json: json, onAccess: onAccess, pathPrefix: codingPath,
        dateDecodingStrategy: dateDecodingStrategy,
        dataDecodingStrategy: dataDecodingStrategy,
        decimalDecodingStrategy: decimalDecodingStrategy))
  }

  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    throw DecodingError.typeMismatch(
      JSON.self,
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription:
          "Expected a JSON object for extras wrapper; unkeyed container is not supported"))
  }

  func singleValueContainer() throws -> SingleValueDecodingContainer {
    throw DecodingError.typeMismatch(
      JSON.self,
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription:
          "Expected a JSON object for extras wrapper; single-value container is not supported"))
  }
}

/// A keyed decoding container that records which keys were accessed.
private struct _TrackingKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
  let json: JSON
  let onAccess: (String) -> Void
  let codingPath: [CodingKey]
  let dateDecodingStrategy: DateDecodingStrategy
  let dataDecodingStrategy: DataDecodingStrategy
  let decimalDecodingStrategy: DecimalDecodingStrategy

  init(
    json: JSON,
    onAccess: @escaping (String) -> Void,
    pathPrefix: [CodingKey],
    dateDecodingStrategy: DateDecodingStrategy = .deferredToDate,
    dataDecodingStrategy: DataDecodingStrategy = .base64,
    decimalDecodingStrategy: DecimalDecodingStrategy = .asString
  ) {
    self.json = json
    self.onAccess = onAccess
    self.codingPath = pathPrefix
    self.dateDecodingStrategy = dateDecodingStrategy
    self.dataDecodingStrategy = dataDecodingStrategy
    self.decimalDecodingStrategy = decimalDecodingStrategy
  }

  var allKeys: [Key] {
    guard case .object(let dict) = json.storage else { return [] }
    return dict.keys.compactMap { Key(stringValue: $0) }
  }

  func contains(_ key: Key) -> Bool {
    onAccess(key.stringValue)
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
    return try valueForKey(key) { try $0.requireBool() }
  }

  func decode(_ type: String.Type, forKey key: Key) throws -> String {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireString() }
  }

  func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireInt64() }
  }

  func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireInt() }
  }

  func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireDouble() }
  }

  func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireFloat() }
  }

  // MARK: - Integer and unsigned widths

  func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireInt8() }
  }

  func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireInt16() }
  }

  func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireInt32() }
  }

  func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireUInt() }
  }

  func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireUInt8() }
  }

  func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireUInt16() }
  }

  func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireUInt32() }
  }

  func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    onAccess(key.stringValue)
    return try valueForKey(key) { try $0.requireUInt64() }
  }

  func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
    onAccess(key.stringValue)
    guard case .object(let dict) = json.storage, let val = dict[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key '\(key.stringValue)' not found"))
    }
    let decoder = _JSONDecodeImpl(
      json: val, userInfo: [:], codingPath: codingPath + [key],
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy)
    return try T(from: decoder)
  }

  func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type, forKey key: Key
  ) throws -> KeyedDecodingContainer<NestedKey> {
    onAccess(key.stringValue)
    guard case .object(let dict) = json.storage, let val = dict[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key '\(key.stringValue)' not found"))
    }
    return KeyedDecodingContainer(
      _TrackingKeyedDecodingContainer<NestedKey>(
        json: val, onAccess: onAccess, pathPrefix: codingPath + [key],
        dateDecodingStrategy: dateDecodingStrategy,
        dataDecodingStrategy: dataDecodingStrategy,
        decimalDecodingStrategy: decimalDecodingStrategy))
  }

  func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    onAccess(key.stringValue)
    guard case .object(let dict) = json.storage, let val = dict[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key '\(key.stringValue)' not found"))
    }
    guard case .array(let elements) = val.storage else {
      throw DecodingError.typeMismatch(
        JSON.self,
        DecodingError.Context(
          codingPath: codingPath + [key],
          debugDescription: "Expected an array"))
    }
    return _JSONUnkeyedDecodingContainer(
      elements: elements,
      impl: _JSONDecodeImpl(
        json: val, userInfo: [:], codingPath: codingPath + [key],
        dateDecodingStrategy: dateDecodingStrategy,
        dataDecodingStrategy: dataDecodingStrategy,
        decimalDecodingStrategy: decimalDecodingStrategy),
      pathPrefix: codingPath + [key])
  }

  func superDecoder(forKey key: Key) throws -> Decoder {
    onAccess(key.stringValue)
    guard case .object(let dict) = json.storage, let val = dict[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key '\(key.stringValue)' not found"))
    }
    return _TrackingDecoder(
      json: val, onAccess: onAccess, codingPath: codingPath + [key],
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy)
  }

  func superDecoder() throws -> Decoder {
    _TrackingDecoder(
      json: json, onAccess: onAccess, codingPath: codingPath,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy)
  }

  /// Helper: extract a value for a key, with key-not-found handling.
  private func valueForKey<T>(_ key: Key, _ extract: (JSON) throws -> T) throws -> T {
    guard case .object(let dict) = json.storage, let val = dict[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key '\(key.stringValue)' not found"))
    }
    return try extract(val)
  }
}

/// An encoder wrapper that only encodes known keys (used for encoding `T`).
private struct _ValueEncoder: Encoder {
  let container: KeyedEncodingContainer<_ExtrasKey>
  let codingPath: [CodingKey] = []
  let userInfo: [CodingUserInfoKey: Any] = [:]

  func container<Key: CodingKey>(keyedBy keyType: Key.Type) -> KeyedEncodingContainer<Key> {
    return KeyedEncodingContainer(
      _FilteredKeyedEncodingContainer<Key>(container: container))
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    fatalError("Unkeyed container is not supported for extras wrapper encoding")
  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    fatalError("Single-value container is not supported for extras wrapper encoding")
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
