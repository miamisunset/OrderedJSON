import Foundation
import OrderedCollections

/// A JSON decoder that produces `JSON` values with preserved key order.
///
/// Unlike `JSONDecoder` from Foundation, `OrderedJSONDecoder` preserves the
/// order of keys when decoding into `JSON` values. For standard `Codable`
/// types like structs, key order is not preserved by the `Codable` protocol
/// itself, but `JSON` values decoded via this decoder retain insertion order.
///
/// ## Example
///
/// ```swift
/// let json = try OrderedJSONDecoder().decode(
///   JSON.self,
///   from: Data(#"{"z": 1, "a": 2}"#.utf8))
/// // json is a JSON object with keys in order: ["z", "a"]
/// ```
public struct OrderedJSONDecoder {
  /// Any user-provided contextual information.
  public var userInfo: [CodingUserInfoKey: Any]

  public init() {
    self.userInfo = [:]
  }

  /// Decodes a `Decodable` value from JSON data, preserving key order.
  ///
  /// - Parameter type: The type to decode.
  /// - Parameter data: UTF-8 encoded JSON data.
  /// - Returns: A decoded value of the requested type.
  /// - Throws: `JSONParseError` for invalid JSON, or decoding errors.
  public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    let json = try JSON.parse(data)
    return try decode(type, from: json)
  }

  /// Decodes a `Decodable` value from a JSON string, preserving key order.
  ///
  /// - Parameter type: The type to decode.
  /// - Parameter string: A JSON string.
  /// - Returns: A decoded value of the requested type.
  /// - Throws: `JSONParseError` for invalid JSON, or decoding errors.
  public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
    let json = try JSON.parse(string)
    return try decode(type, from: json)
  }

  /// Decodes a `Decodable` value from a `JSON` value.
  ///
  /// - Parameter type: The type to decode.
  /// - Parameter json: A `JSON` value.
  /// - Returns: A decoded value of the requested type.
  /// - Throws: Decoding errors.
  public func decode<T: Decodable>(_ type: T.Type, from json: JSON) throws -> T {
    let impl = _JSONDecodeImpl(json: json, userInfo: userInfo)
    return try T(from: impl)
  }
}

// MARK: - Internal decoder implementation

/// The concrete `Decoder` implementation used by `OrderedJSONDecoder`.
final class _JSONDecodeImpl: Decoder {
  /// The JSON value being decoded.
  let json: JSON

  /// The coding path from the root to the current decoding point.
  let codingPath: [CodingKey] = []

  /// User-provided contextual information.
  var userInfo: [CodingUserInfoKey: Any] { _userInfo }

  private let _userInfo: [CodingUserInfoKey: Any]

  init(json: JSON, userInfo: [CodingUserInfoKey: Any] = [:]) {
    self.json = json
    self._userInfo = userInfo
  }

  func container<Key: CodingKey>(keyedBy keyType: Key.Type) throws -> KeyedDecodingContainer<Key> {
    guard case .object(let dict) = json.storage else {
      throw DecodingError.typeMismatch(
        JSON.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected a JSON object"))
    }
    let container = _JSONKeyedDecodingContainer<Key>(dictionary: dict, encoder: self)
    return KeyedDecodingContainer(container)
  }

  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    guard case .array(let elements) = json.storage else {
      throw DecodingError.typeMismatch(
        JSON.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected a JSON array"))
    }
    return _JSONUnkeyedDecodingContainer(elements: elements, encoder: self)
  }

  func singleValueContainer() throws -> SingleValueDecodingContainer {
    _JSONSingleValueDecodingContainer(json: json, encoder: self)
  }
}

// MARK: - Keyed decoding container

struct _JSONKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
  let codingPath: [CodingKey] = []
  let allKeys: [Key]

  private let dictionary: OrderedDictionary<String, JSON>
  private let encoder: _JSONDecodeImpl

  init(dictionary: OrderedDictionary<String, JSON>, encoder: _JSONDecodeImpl) {
    self.dictionary = dictionary
    self.encoder = encoder
    self.allKeys = dictionary.keys.compactMap { Key(stringValue: $0) }
  }

  func contains(_ key: Key) -> Bool {
    dictionary[key.stringValue] != nil
  }

  func decodeNil(forKey key: Key) throws -> Bool {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath, debugDescription: "Key not found: \(key.stringValue)"))
    }
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

  func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath, debugDescription: "Key not found: \(key.stringValue)"))
    }
    let child = _JSONDecodeImpl(json: value, userInfo: encoder.userInfo)
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
          codingPath: codingPath, debugDescription: "Key not found: \(key.stringValue)"))
    }
    let child = _JSONDecodeImpl(json: value, userInfo: encoder.userInfo)
    return try child.container(keyedBy: keyType)
  }

  func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath, debugDescription: "Key not found: \(key.stringValue)"))
    }
    let child = _JSONDecodeImpl(json: value, userInfo: encoder.userInfo)
    return try child.unkeyedContainer()
  }

  func superDecoder(forKey key: Key) throws -> Decoder {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath, debugDescription: "Key not found: \(key.stringValue)"))
    }
    return _JSONDecodeImpl(json: value, userInfo: encoder.userInfo)
  }

  func superDecoder() throws -> Decoder {
    // The super decoder for the entire container; not commonly used.
    return _JSONDecodeImpl(json: .object(dictionary), userInfo: encoder.userInfo)
  }

  /// Helper: extract a typed value from the dictionary, with key-not-found handling.
  private func valueForKey<T>(_ key: Key, _ extract: (JSON) throws -> T?) throws -> T {
    guard let value = dictionary[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key,
        DecodingError.Context(
          codingPath: codingPath, debugDescription: "Key not found: \(key.stringValue)"))
    }
    guard let result = try extract(value) else {
      throw DecodingError.typeMismatch(
        T.self,
        DecodingError.Context(
          codingPath: codingPath, debugDescription: "Type mismatch for key \(key.stringValue)"))
    }
    return result
  }
}

// MARK: - Unkeyed decoding container

struct _JSONUnkeyedDecodingContainer: UnkeyedDecodingContainer {
  let codingPath: [CodingKey] = []
  let count: Int?
  var currentIndex: Int = 0
  var isAtEnd: Bool { currentIndex >= (elements.count) }

  private let elements: [JSON]
  private let encoder: _JSONDecodeImpl

  init(elements: [JSON], encoder: _JSONDecodeImpl) {
    self.elements = elements
    self.encoder = encoder
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

  mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
    let value = try currentElement()
    let child = _JSONDecodeImpl(json: value, userInfo: encoder.userInfo)
    return try T(from: child)
  }

  mutating func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type
  ) throws -> KeyedDecodingContainer<NestedKey> {
    let value = try currentElement()
    let child = _JSONDecodeImpl(json: value, userInfo: encoder.userInfo)
    return try child.container(keyedBy: keyType)
  }

  mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
    let value = try currentElement()
    let child = _JSONDecodeImpl(json: value, userInfo: encoder.userInfo)
    return try child.unkeyedContainer()
  }

  mutating func superDecoder() throws -> Decoder {
    let value = try currentElement()
    return _JSONDecodeImpl(json: value, userInfo: encoder.userInfo)
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
  let codingPath: [CodingKey] = []

  private let json: JSON
  private let encoder: _JSONDecodeImpl

  init(json: JSON, encoder: _JSONDecodeImpl) {
    self.json = json
    self.encoder = encoder
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

  func decode<T: Decodable>(_ type: T.Type) throws -> T {
    let child = _JSONDecodeImpl(json: json, userInfo: encoder.userInfo)
    return try T(from: child)
  }
}
