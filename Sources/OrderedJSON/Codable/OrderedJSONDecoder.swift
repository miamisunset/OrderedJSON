import Foundation
import OrderedCollections

/// A JSON decoder that produces `JSON` values with preserved key order.
public struct OrderedJSONDecoder {
  public var userInfo: [CodingUserInfoKey: Any]

  public init() {
    self.userInfo = [:]
  }

  public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    let json = try JSON.parse(data)
    return try decode(type, from: json)
  }

  public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
    let json = try JSON.parse(string)
    return try decode(type, from: json)
  }

  public func decode<T: Decodable>(_ type: T.Type, from json: JSON) throws -> T {
    let impl = _JSONDecodeImpl(json: json, userInfo: userInfo)
    return try T(from: impl)
  }
}

// MARK: - Internal decoder implementation

final class _JSONDecodeImpl: Decoder {
  let json: JSON
  let codingPath: [CodingKey]
  var userInfo: [CodingUserInfoKey: Any] { _userInfo }
  private let _userInfo: [CodingUserInfoKey: Any]

  init(json: JSON, userInfo: [CodingUserInfoKey: Any] = [:], codingPath: [CodingKey] = []) {
    self.json = json
    self._userInfo = userInfo
    self.codingPath = codingPath
  }

  func container<Key: CodingKey>(keyedBy keyType: Key.Type) throws -> KeyedDecodingContainer<Key> {
    guard case .object(let dict) = json.storage else {
      throw DecodingError.typeMismatch(
        JSON.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected a JSON object"))
    }
    return KeyedDecodingContainer(
      _JSONKeyedDecodingContainer<Key>(
        dictionary: dict, impl: self, pathPrefix: codingPath))
  }

  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    guard case .array(let elements) = json.storage else {
      throw DecodingError.typeMismatch(
        JSON.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected a JSON array"))
    }
    return _JSONUnkeyedDecodingContainer(
      elements: elements, impl: self, pathPrefix: codingPath)
  }

  func singleValueContainer() throws -> SingleValueDecodingContainer {
    _JSONSingleValueDecodingContainer(json: json, impl: self, pathPrefix: codingPath)
  }
}

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
    self.codingPath = pathPrefix
    self.allKeys = dictionary.keys.compactMap { Key(stringValue: $0) }
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

  func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    try valueForKey(key, { try $0.requireBool() })
  }

  func decode(_ type: String.Type, forKey key: Key) throws -> String {
    try valueForKey(key, { try $0.requireString() })
  }

  func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    try valueForKey(key, { try $0.requireInt64() })
  }

  func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    try valueForKey(key, { try $0.requireInt() })
  }

  func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    try valueForKey(key, { try $0.requireDouble() })
  }

  func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    try valueForKey(key, { try $0.requireFloat() })
  }

  // MARK: - Integer and unsigned widths

  func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    try valueForKey(key, { try $0.requireInt8() })
  }

  func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
    try valueForKey(key, { try $0.requireInt16() })
  }

  func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
    try valueForKey(key, { try $0.requireInt32() })
  }

  func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    try valueForKey(key, { try $0.requireUInt() })
  }

  func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
    try valueForKey(key, { try $0.requireUInt8() })
  }

  func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    try valueForKey(key, { try $0.requireUInt16() })
  }

  func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    try valueForKey(key, { try $0.requireUInt32() })
  }

  func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    try valueForKey(key, { try $0.requireUInt64() })
  }

  func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key not found: \(key.stringValue)"))
    }
    let child = _JSONDecodeImpl(
      json: value, userInfo: impl.userInfo, codingPath: codingPath + [key])
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
          debugDescription: "Key not found: \(key.stringValue)"))
    }
    let child = _JSONDecodeImpl(
      json: value, userInfo: impl.userInfo, codingPath: codingPath + [key])
    return try child.container(keyedBy: keyType)
  }

  func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key not found: \(key.stringValue)"))
    }
    let child = _JSONDecodeImpl(
      json: value, userInfo: impl.userInfo, codingPath: codingPath + [key])
    return try child.unkeyedContainer()
  }

  func superDecoder(forKey key: Key) throws -> Decoder {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key not found: \(key.stringValue)"))
    }
    return _JSONDecodeImpl(json: value, userInfo: impl.userInfo, codingPath: codingPath + [key])
  }

  func superDecoder() throws -> Decoder {
    _JSONDecodeImpl(json: .object(dictionary), userInfo: impl.userInfo, codingPath: codingPath)
  }

  /// Helper: extract a typed value from the dictionary, with key-not-found handling.
  private func valueForKey<T>(_ key: Key, _ extract: (JSON) throws -> T) throws -> T {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Key not found: \(key.stringValue)"))
    }
    return try extract(value)
  }
}

// MARK: - Unkeyed decoding container

struct _JSONUnkeyedDecodingContainer: UnkeyedDecodingContainer {
  let codingPath: [CodingKey]
  let count: Int?
  var currentIndex: Int = 0
  var isAtEnd: Bool { currentIndex >= (elements.count) }

  private let elements: [JSON]
  private let impl: _JSONDecodeImpl

  init(elements: [JSON], impl: _JSONDecodeImpl, pathPrefix: [CodingKey]) {
    self.elements = elements
    self.impl = impl
    self.codingPath = pathPrefix
    self.count = elements.count
  }

  mutating func decodeNil() throws -> Bool {
    let value = try currentElement()
    if case .null = value.storage { return true }
    return false
  }

  mutating func decode(_ type: Bool.Type) throws -> Bool {
    try currentElement().requireBool()
  }

  mutating func decode(_ type: String.Type) throws -> String {
    try currentElement().requireString()
  }

  mutating func decode(_ type: Int64.Type) throws -> Int64 {
    try currentElement().requireInt64()
  }

  mutating func decode(_ type: Int.Type) throws -> Int {
    try currentElement().requireInt()
  }

  mutating func decode(_ type: Double.Type) throws -> Double {
    try currentElement().requireDouble()
  }

  mutating func decode(_ type: Float.Type) throws -> Float {
    try currentElement().requireFloat()
  }

  // MARK: - Integer and unsigned widths

  mutating func decode(_ type: Int8.Type) throws -> Int8 {
    try currentElement().requireInt8()
  }

  mutating func decode(_ type: Int16.Type) throws -> Int16 {
    try currentElement().requireInt16()
  }

  mutating func decode(_ type: Int32.Type) throws -> Int32 {
    try currentElement().requireInt32()
  }

  mutating func decode(_ type: UInt.Type) throws -> UInt {
    try currentElement().requireUInt()
  }

  mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
    try currentElement().requireUInt8()
  }

  mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
    try currentElement().requireUInt16()
  }

  mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
    try currentElement().requireUInt32()
  }

  mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
    try currentElement().requireUInt64()
  }

  mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
    let value = try currentElement()
    let child = _JSONDecodeImpl(json: value, userInfo: impl.userInfo, codingPath: codingPath)
    return try T(from: child)
  }

  mutating func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type
  ) throws -> KeyedDecodingContainer<NestedKey> {
    let value = try currentElement()
    let child = _JSONDecodeImpl(json: value, userInfo: impl.userInfo, codingPath: codingPath)
    return try child.container(keyedBy: keyType)
  }

  mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
    let value = try currentElement()
    let child = _JSONDecodeImpl(json: value, userInfo: impl.userInfo, codingPath: codingPath)
    return try child.unkeyedContainer()
  }

  mutating func superDecoder() throws -> Decoder {
    let value = try currentElement()
    return _JSONDecodeImpl(json: value, userInfo: impl.userInfo, codingPath: codingPath)
  }

  private mutating func currentElement() throws -> JSON {
    guard currentIndex < elements.count else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Array index \(currentIndex) out of bounds"))
    }
    defer { currentIndex += 1 }
    return elements[currentIndex]
  }
}

// MARK: - Single-value decoding container

struct _JSONSingleValueDecodingContainer: SingleValueDecodingContainer {
  let codingPath: [CodingKey]

  private let json: JSON
  private let impl: _JSONDecodeImpl

  init(json: JSON, impl: _JSONDecodeImpl, pathPrefix: [CodingKey]) {
    self.json = json
    self.impl = impl
    self.codingPath = pathPrefix
  }

  func decodeNil() -> Bool {
    if case .null = json.storage { return true }
    return false
  }

  func decode(_ type: Bool.Type) throws -> Bool {
    try json.requireBool()
  }

  func decode(_ type: String.Type) throws -> String {
    try json.requireString()
  }

  func decode(_ type: Int64.Type) throws -> Int64 {
    try json.requireInt64()
  }

  func decode(_ type: Int.Type) throws -> Int {
    try json.requireInt()
  }

  func decode(_ type: Double.Type) throws -> Double {
    try json.requireDouble()
  }

  func decode(_ type: Float.Type) throws -> Float {
    try json.requireFloat()
  }

  // MARK: - Integer and unsigned widths

  func decode(_ type: Int8.Type) throws -> Int8 {
    try json.requireInt8()
  }

  func decode(_ type: Int16.Type) throws -> Int16 {
    try json.requireInt16()
  }

  func decode(_ type: Int32.Type) throws -> Int32 {
    try json.requireInt32()
  }

  func decode(_ type: UInt.Type) throws -> UInt {
    try json.requireUInt()
  }

  func decode(_ type: UInt8.Type) throws -> UInt8 {
    try json.requireUInt8()
  }

  func decode(_ type: UInt16.Type) throws -> UInt16 {
    try json.requireUInt16()
  }

  func decode(_ type: UInt32.Type) throws -> UInt32 {
    try json.requireUInt32()
  }

  func decode(_ type: UInt64.Type) throws -> UInt64 {
    try json.requireUInt64()
  }

  func decode<T: Decodable>(_ type: T.Type) throws -> T {
    let child = _JSONDecodeImpl(json: json, userInfo: impl.userInfo, codingPath: codingPath)
    return try T(from: child)
  }
}
