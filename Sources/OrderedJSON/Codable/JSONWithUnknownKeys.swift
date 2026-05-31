import Foundation
import OrderedCollections

/// A wrapper that captures unknown JSON keys during decoding.
///
/// `JSONWithUnknownKeys` is useful when you want to decode a known set of fields
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
///   JSONWithUnknownKeys<Person>.self, from: data)
/// // wrapped.value.name == "Alice"
/// // wrapped.value.age == 30
/// // wrapped.unknownKeys["color"] == "blue"
/// // wrapped.unknownKeys["city"] == "NYC"
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
/// - **Unknown keys must be a JSON object**: When encoding, `unknownKeys` must be a JSON
///   object; encoding non-object unknown keys throws `EncodingError.invalidValue`.
/// - **Set `userInfo` before calling**: The encoder/decoder copies `userInfo`
///   at construction time; mutations after calling `encode`/`decode` do not
///   propagate to nested containers.
public struct JSONWithUnknownKeys<T: Decodable>: Decodable {
  /// The decoded value of known fields.
  public let value: T

  /// Any unknown keys not part of `T`, captured as a JSON object.
  public let unknownKeys: JSON

  public init(value: T, unknownKeys: JSON) {
    self.value = value
    self.unknownKeys = unknownKeys
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
      decimalDecodingStrategy: decimalDecodingStrategy
    )
    value = try T(from: trackingDecoder)

    // Step 3: Remaining keys are extras
    var extrasDict = OrderedDictionary<String, JSON>()
    for (key, value) in dict where !usedKeys.contains(key) {
      extrasDict[key] = value
    }
    unknownKeys = .object(extrasDict)
  }
}

extension JSONWithUnknownKeys: Encodable where T: Encodable {
  /// Encodes both the known fields and extras into a single JSON object.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: _ExtrasKey.self)

    // Encode known fields
    try value.encode(to: _ValueEncoder(container: container))

    // Encode unknown keys — must be a JSON object
    guard case .object(let extrasDict) = unknownKeys.storage else {
      throw EncodingError.invalidValue(
        unknownKeys,
        EncodingError.Context(
          codingPath: encoder.codingPath,
          debugDescription: "Unknown keys must be a JSON object, got \(unknownKeys.typeName)"
        )
      )
    }
    for (key, value) in extrasDict {
      try container.encode(value, forKey: _ExtrasKey(stringValue: key))
    }
  }
}

// MARK: - Internal helpers

/// A `CodingKey` that maps any string key.
struct _ExtrasKey: CodingKey {
  let stringValue: String
  let intValue: Int?
  init(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init(intValue: Int) {
    stringValue = "\(intValue)"
    self.intValue = intValue
  }
}

/// An encoder wrapper that only encodes known keys (used for encoding `T`).
private struct _ValueEncoder: Encoder {
  let container: KeyedEncodingContainer<_ExtrasKey>
  let codingPath: [CodingKey] = []
  let userInfo: [CodingUserInfoKey: Any] = [:]

  func container<Key: CodingKey>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> {
    return KeyedEncodingContainer(
      _FilteredKeyedEncodingContainer<Key>(container: container)
    )
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
      keyedBy: keyType, forKey: _ExtrasKey(stringValue: key.stringValue)
    )
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
