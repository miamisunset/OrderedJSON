import Foundation
import OrderedCollections

// MARK: - Keyed decoding container

struct _JSONKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
  let codingPath: [CodingKey]
  let allKeys: [Key]

  private let dictionary: OrderedDictionary<String, JSON>
  private let impl: _JSONDecodeImpl

  init(dictionary: OrderedDictionary<String, JSON>, impl: _JSONDecodeImpl, pathPrefix: [CodingKey])
  {
    self.dictionary = dictionary
    self.impl = impl
    codingPath = pathPrefix
    allKeys = dictionary.keys.compactMap { Key(stringValue: $0) }
  }

  func contains(_ key: Key) -> Bool {
    dictionary[key.stringValue] != nil
  }

  func decodeNil(forKey key: Key) throws -> Bool {
    // Per Foundation convention: return true for absent keys too.
    // This allows decodeIfPresent to distinguish "missing" from "explicit null"
    // via contains + decodeNil.
    guard let value = dictionary[key.stringValue] else { return true }
    if case .null = value.storage { return true }
    return false
  }

  func decode(_: Bool.Type, forKey key: Key) throws -> Bool {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireBool() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: String.Type, forKey key: Key) throws -> String {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireString() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireInt64() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: Int.Type, forKey key: Key) throws -> Int {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireInt() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: Double.Type, forKey key: Key) throws -> Double {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireDouble() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: Float.Type, forKey key: Key) throws -> Float {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireFloat() }, codingPath: codingPath + [key])
    }
  }

  // MARK: - Integer and unsigned widths

  func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireInt8() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireInt16() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireInt32() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireUInt() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireUInt8() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireUInt16() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireUInt32() }, codingPath: codingPath + [key])
    }
  }

  func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
    try valueForKey(key) { json in
      try decodeJSON({ try json.requireUInt64() }, codingPath: codingPath + [key])
    }
  }

  func decode<T: Decodable>(_: T.Type, forKey key: Key) throws -> T {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key not found: \(key.stringValue)"
        )
      )
    }
    // Foundation type special handling
    if T.self == Date.self {
      return try decodeDate(
        from: value, with: impl.dateDecodingStrategy, codingPath: codingPath + [key],
        dateDecodingStrategy: impl.dateDecodingStrategy,
        dataDecodingStrategy: impl.dataDecodingStrategy,
        decimalDecodingStrategy: impl.decimalDecodingStrategy
      ) as! T
    }
    if T.self == Data.self {
      return try decodeData(
        from: value, with: impl.dataDecodingStrategy, codingPath: codingPath + [key],
        dateDecodingStrategy: impl.dateDecodingStrategy,
        dataDecodingStrategy: impl.dataDecodingStrategy,
        decimalDecodingStrategy: impl.decimalDecodingStrategy
      ) as! T
    }
    if T.self == URL.self {
      return try decodeURL(from: value, codingPath: codingPath + [key]) as! T
    }
    if T.self == UUID.self {
      return try decodeUUID(from: value, codingPath: codingPath + [key]) as! T
    }
    if T.self == Decimal.self {
      return try decodeDecimal(
        from: value, with: impl.decimalDecodingStrategy, codingPath: codingPath + [key]
      ) as! T
    }
    // Default path
    let child = _JSONDecodeImpl(
      json: value,
      userInfo: impl.userInfo,
      codingPath: codingPath + [key],
      dateDecodingStrategy: impl.dateDecodingStrategy,
      dataDecodingStrategy: impl.dataDecodingStrategy,
      decimalDecodingStrategy: impl.decimalDecodingStrategy
    )
    return try T(from: child)
  }

  func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type,
    forKey key: Key
  ) throws -> KeyedDecodingContainer<NestedKey> {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key not found: \(key.stringValue)"
        )
      )
    }
    let child = _JSONDecodeImpl(
      json: value,
      userInfo: impl.userInfo,
      codingPath: codingPath + [key],
      dateDecodingStrategy: impl.dateDecodingStrategy,
      dataDecodingStrategy: impl.dataDecodingStrategy,
      decimalDecodingStrategy: impl.decimalDecodingStrategy
    )
    return try child.container(keyedBy: keyType)
  }

  func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key not found: \(key.stringValue)"
        )
      )
    }
    let child = _JSONDecodeImpl(
      json: value,
      userInfo: impl.userInfo,
      codingPath: codingPath + [key],
      dateDecodingStrategy: impl.dateDecodingStrategy,
      dataDecodingStrategy: impl.dataDecodingStrategy,
      decimalDecodingStrategy: impl.decimalDecodingStrategy
    )
    return try child.unkeyedContainer()
  }

  func superDecoder(forKey key: Key) throws -> Decoder {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key not found: \(key.stringValue)"
        )
      )
    }
    return _JSONDecodeImpl(
      json: value,
      userInfo: impl.userInfo,
      codingPath: codingPath + [key],
      dateDecodingStrategy: impl.dateDecodingStrategy,
      dataDecodingStrategy: impl.dataDecodingStrategy,
      decimalDecodingStrategy: impl.decimalDecodingStrategy
    )
  }

  func superDecoder() throws -> Decoder {
    _JSONDecodeImpl(
      json: .object(dictionary),
      userInfo: impl.userInfo,
      codingPath: codingPath,
      dateDecodingStrategy: impl.dateDecodingStrategy,
      dataDecodingStrategy: impl.dataDecodingStrategy,
      decimalDecodingStrategy: impl.decimalDecodingStrategy
    )
  }

  /// Helper: extract a typed value from the dictionary, with key-not-found handling.
  private func valueForKey<T>(_ key: Key, _ extract: (JSON) throws -> T) throws -> T {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key not found: \(key.stringValue)"
        )
      )
    }
    return try extract(value)
  }
}
