import Foundation
import OrderedCollections

// MARK: - Internal helpers

/// A decoder that tracks which keys were accessed during decoding.
struct _TrackingDecoder: Decoder {
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

  func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
    return KeyedDecodingContainer(
      _TrackingKeyedDecodingContainer<Key>(
        json: json, onAccess: onAccess, pathPrefix: codingPath,
        dateDecodingStrategy: dateDecodingStrategy,
        dataDecodingStrategy: dataDecodingStrategy,
        decimalDecodingStrategy: decimalDecodingStrategy
      )
    )
  }

  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    throw DecodingError.typeMismatch(
      JSON.self,
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription:
          "Expected a JSON object for extras wrapper; unkeyed container is not supported"
      )
    )
  }

  func singleValueContainer() throws -> SingleValueDecodingContainer {
    throw DecodingError.typeMismatch(
      JSON.self,
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription:
          "Expected a JSON object for extras wrapper; single-value container is not supported"
      )
    )
  }
}

/// A keyed decoding container that records which keys were accessed.
struct _TrackingKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
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
    codingPath = pathPrefix
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

  func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireBool() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: String.Type, forKey key: Key) throws -> String {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireString() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireInt64() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: Int.Type, forKey key: Key) throws -> Int {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireInt() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: Double.Type, forKey key: Key) throws -> Double {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireDouble() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: Float.Type, forKey key: Key) throws -> Float {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireFloat() }, codingPath: codingPath + [key])
    }
  }

  // MARK: - Integer and unsigned widths

  func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireInt8() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireInt16() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireInt32() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireUInt() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireUInt8() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireUInt16() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireUInt32() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
    onAccess(key.stringValue)
    return try valueForKey(key) { json in
      try decodeJSON({ try json.requireUInt64() }, codingPath: codingPath + [key])
    }
  }

  func decode<T: Decodable>(_: T.Type, forKey key: Key) throws -> T {
    onAccess(key.stringValue)
    guard case .object(let dict) = json.storage, let val = dict[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key '\(key.stringValue)' not found"
        )
      )
    }
    // Foundation type special handling (mirrors OrderedJSONDecoder)
    if T.self == Date.self {
      return try decodeDate(
        from: val, with: dateDecodingStrategy, codingPath: codingPath + [key],
        dateDecodingStrategy: dateDecodingStrategy,
        dataDecodingStrategy: dataDecodingStrategy,
        decimalDecodingStrategy: decimalDecodingStrategy
      ) as! T
    }
    if T.self == Data.self {
      return try decodeData(
        from: val, with: dataDecodingStrategy, codingPath: codingPath + [key],
        dateDecodingStrategy: dateDecodingStrategy,
        dataDecodingStrategy: dataDecodingStrategy,
        decimalDecodingStrategy: decimalDecodingStrategy
      ) as! T
    }
    if T.self == URL.self {
      return try decodeURL(from: val, codingPath: codingPath + [key]) as! T
    }
    if T.self == UUID.self {
      return try decodeUUID(from: val, codingPath: codingPath + [key]) as! T
    }
    if T.self == Decimal.self {
      return try decodeDecimal(
        from: val, with: decimalDecodingStrategy, codingPath: codingPath + [key]
      ) as! T
    }
    // Default path
    let decoder = _JSONDecodeImpl(
      json: val, userInfo: [:], codingPath: codingPath + [key],
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
    return try T(from: decoder)
  }

  func nestedContainer<NestedKey: CodingKey>(
    keyedBy _: NestedKey.Type, forKey key: Key
  ) throws -> KeyedDecodingContainer<NestedKey> {
    onAccess(key.stringValue)
    guard case .object(let dict) = json.storage, let val = dict[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key '\(key.stringValue)' not found"
        )
      )
    }
    return KeyedDecodingContainer(
      _TrackingKeyedDecodingContainer<NestedKey>(
        json: val, onAccess: onAccess, pathPrefix: codingPath + [key],
        dateDecodingStrategy: dateDecodingStrategy,
        dataDecodingStrategy: dataDecodingStrategy,
        decimalDecodingStrategy: decimalDecodingStrategy
      )
    )
  }

  func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    onAccess(key.stringValue)
    guard case .object(let dict) = json.storage, let val = dict[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key '\(key.stringValue)' not found"
        )
      )
    }
    guard case .array(let elements) = val.storage else {
      throw DecodingError.typeMismatch(
        JSON.self,
        DecodingError.Context(
          codingPath: codingPath + [key],
          debugDescription: "Expected an array"
        )
      )
    }
    return _JSONUnkeyedDecodingContainer(
      elements: elements,
      impl: _JSONDecodeImpl(
        json: val, userInfo: [:], codingPath: codingPath + [key],
        dateDecodingStrategy: dateDecodingStrategy,
        dataDecodingStrategy: dataDecodingStrategy,
        decimalDecodingStrategy: decimalDecodingStrategy
      ),
      pathPrefix: codingPath + [key]
    )
  }

  func superDecoder(forKey key: Key) throws -> Decoder {
    onAccess(key.stringValue)
    guard case .object(let dict) = json.storage, let val = dict[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key '\(key.stringValue)' not found"
        )
      )
    }
    return _TrackingDecoder(
      json: val, onAccess: onAccess, codingPath: codingPath + [key],
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
  }

  func superDecoder() throws -> Decoder {
    _TrackingDecoder(
      json: json, onAccess: onAccess, codingPath: codingPath,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
  }

  /// Helper: extract a value for a key, with key-not-found handling.
  private func valueForKey<T>(_ key: Key, _ extract: (JSON) throws -> T) throws -> T {
    guard case .object(let dict) = json.storage, let val = dict[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key '\(key.stringValue)' not found"
        )
      )
    }
    return try extract(val)
  }
}
