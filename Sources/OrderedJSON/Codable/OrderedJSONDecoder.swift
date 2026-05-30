import Foundation
import OrderedCollections

/// A JSON decoder that produces `JSON` values with preserved key order.
///
/// - Important: Set `userInfo` before calling `decode`;
///   mutations after the call do not propagate to nested containers.
public struct OrderedJSONDecoder {
  /// The user info dictionary for the decoder, propagated to all nested decoders.
  public var userInfo: [CodingUserInfoKey: Any]

  /// The strategy to use for decoding `Date` values.
  public var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate

  /// The strategy to use for decoding `Data` values.
  public var dataDecodingStrategy: DataDecodingStrategy = .base64

  /// The strategy to use for decoding `Decimal` values.
  public var decimalDecodingStrategy: DecimalDecodingStrategy = .asString

  /// Creates a new decoder with default options.
  public init() {
    userInfo = [:]
  }

  public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    let json = try JSON.parse(data)
    return try decode(type, from: json)
  }

  public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
    let json = try JSON.parse(string)
    return try decode(type, from: json)
  }

  public func decode<T: Decodable>(_: T.Type, from json: JSON) throws -> T {
    let impl = _JSONDecodeImpl(
      json: json,
      userInfo: userInfo,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
    return try T(from: impl)
  }
}

// MARK: - Decoding strategies

/// Strategy for decoding `Date` values.
public enum DateDecodingStrategy {
  /// Decode the `Date` using its `Decodable` implementation (default).
  case deferredToDate
  /// Decode as a Double representing seconds since 1970-01-01.
  case secondsSince1970
  /// Decode as a Double representing milliseconds since 1970-01-01.
  case millisecondsSince1970
  /// Decode as an ISO-8601 string using `ISO8601DateFormatter`.
  case iso8601
  /// Decode using a `DateFormatter`.
  case formatted(DateFormatter)
  /// Decode using a custom closure.
  case custom((JSON, Decoder) throws -> Date)
}

/// Strategy for decoding `Data` values.
public enum DataDecodingStrategy {
  /// Decode the `Data` using its `Decodable` implementation.
  case deferredToData
  /// Decode as a Base64-encoded string (default).
  case base64
  /// Decode using a custom closure.
  case custom((JSON, Decoder) throws -> Data)
}

/// Strategy for decoding `Decimal` values.
public enum DecimalDecodingStrategy {
  /// Decode the `Decimal` from a JSON string (default, preserves precision).
  case asString
  /// Decode the `Decimal` from a JSON number.
  case asNumber
}

// MARK: - Internal decoder implementation

/// The concrete `Decoder` implementation. Wraps a `JSON` value and propagates
/// decoding strategies and user info to all nested containers.
final class _JSONDecodeImpl: Decoder {
  let json: JSON
  let codingPath: [CodingKey]
  var userInfo: [CodingUserInfoKey: Any] {
    _userInfo
  }

  private let _userInfo: [CodingUserInfoKey: Any]

  /// Strategies propagated from `OrderedJSONDecoder`.
  let dateDecodingStrategy: DateDecodingStrategy
  let dataDecodingStrategy: DataDecodingStrategy
  let decimalDecodingStrategy: DecimalDecodingStrategy

  /// Creates a decoder impl for the given JSON value.
  /// - Parameters:
  ///   - json: The JSON value to decode from.
  ///   - userInfo: User info dictionary propagated to nested decoders.
  ///   - codingPath: The coding path for the current decoding context.
  ///   - dateDecodingStrategy: Strategy for decoding `Date` values.
  ///   - dataDecodingStrategy: Strategy for decoding `Data` values.
  ///   - decimalDecodingStrategy: Strategy for decoding `Decimal` values.
  init(
    json: JSON,
    userInfo: [CodingUserInfoKey: Any] = [:],
    codingPath: [CodingKey] = [],
    dateDecodingStrategy: DateDecodingStrategy = .deferredToDate,
    dataDecodingStrategy: DataDecodingStrategy = .base64,
    decimalDecodingStrategy: DecimalDecodingStrategy = .asString
  ) {
    self.json = json
    _userInfo = userInfo
    self.codingPath = codingPath
    self.dateDecodingStrategy = dateDecodingStrategy
    self.dataDecodingStrategy = dataDecodingStrategy
    self.decimalDecodingStrategy = decimalDecodingStrategy
  }

  func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
    guard case .object(let dict) = json.storage else {
      throw DecodingError.typeMismatch(
        JSON.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected a JSON object"
        )
      )
    }
    return KeyedDecodingContainer(
      _JSONKeyedDecodingContainer<Key>(
        dictionary: dict, impl: self, pathPrefix: codingPath
      )
    )
  }

  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    guard case .array(let elements) = json.storage else {
      throw DecodingError.typeMismatch(
        JSON.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected a JSON array"
        )
      )
    }
    return _JSONUnkeyedDecodingContainer(
      elements: elements, impl: self, pathPrefix: codingPath
    )
  }

  func singleValueContainer() throws -> SingleValueDecodingContainer {
    _JSONSingleValueDecodingContainer(json: json, impl: self, pathPrefix: codingPath)
  }
}

// MARK: - Foundation type decoding helpers

/// Wraps a JSONError thrown by a require*() call into DecodingError.dataCorrupted.
package func wrapJSONError<T>(_ expression: () throws -> T, codingPath: [CodingKey],
  debugDescription: String? = nil) throws -> T
{
  do {
    return try expression()
  } catch let error as JSONError {
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription: debugDescription ?? String(describing: error)
      )
    )
  }
}

package func decodeDate(
  from json: JSON, with strategy: DateDecodingStrategy, codingPath: [CodingKey],
  dateDecodingStrategy: DateDecodingStrategy,
  dataDecodingStrategy: DataDecodingStrategy,
  decimalDecodingStrategy: DecimalDecodingStrategy
) throws -> Date {
  switch strategy {
  case .deferredToDate:
    // Fall through to Date's own Decodable implementation
    let impl = _JSONDecodeImpl(
      json: json, codingPath: codingPath,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
    return try Date(from: impl)
  case .secondsSince1970:
    return try Date(timeIntervalSince1970: wrapJSONError({ try json.requireDouble() }, codingPath: codingPath))
  case .millisecondsSince1970:
    return try Date(timeIntervalSince1970: wrapJSONError({ try json.requireDouble() }, codingPath: codingPath) / 1000.0)
  case .iso8601:
    let string = try wrapJSONError({ try json.requireString() }, codingPath: codingPath)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: string) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Invalid ISO8601 date: \(string)"
        )
      )
    }
    return date
  case .formatted(let formatter):
    let string = try wrapJSONError({ try json.requireString() }, codingPath: codingPath)
    guard let date = formatter.date(from: string) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Invalid date format: \(string)"
        )
      )
    }
    return date
  case .custom(let closure):
    let impl = _JSONDecodeImpl(
      json: json, codingPath: codingPath,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
    return try closure(json, impl)
  }
}

package func decodeData(
  from json: JSON, with strategy: DataDecodingStrategy, codingPath: [CodingKey],
  dateDecodingStrategy: DateDecodingStrategy,
  dataDecodingStrategy: DataDecodingStrategy,
  decimalDecodingStrategy: DecimalDecodingStrategy
) throws -> Data {
  switch strategy {
  case .deferredToData:
    // Fall through to Data's own Decodable implementation
    let impl = _JSONDecodeImpl(
      json: json, codingPath: codingPath,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
    return try Data(from: impl)
  case .base64:
    let string = try wrapJSONError({ try json.requireString() }, codingPath: codingPath)
    guard let data = Data(base64Encoded: string) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Invalid base64 data"
        )
      )
    }
    return data
  case .custom(let closure):
    let impl = _JSONDecodeImpl(
      json: json, codingPath: codingPath,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
    return try closure(json, impl)
  }
}

package func decodeDecimal(
  from json: JSON, with strategy: DecimalDecodingStrategy, codingPath: [CodingKey]
) throws -> Decimal {
  switch strategy {
  case .asString:
    let string = try wrapJSONError({ try json.requireString() }, codingPath: codingPath)
    guard let decimal = Decimal(string: string) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Invalid Decimal string: \(string)"
        )
      )
    }
    return decimal
  case .asNumber:
    switch json.storage {
    case .number(.integer(let i)):
      return Decimal(i)
    case .number(.float(let d)):
      return Decimal(Double(d))
    default:
      throw DecodingError.typeMismatch(
        Decimal.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected a JSON number for Decimal decoding"
        )
      )
    }
  }
}

package func decodeURL(
  from json: JSON, codingPath: [CodingKey]
) throws -> URL {
  let string = try wrapJSONError({ try json.requireString() }, codingPath: codingPath)
  guard let url = URL(string: string) else {
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription: "Invalid URL string: \(string)"
      )
    )
  }
  return url
}

package func decodeUUID(
  from json: JSON, codingPath: [CodingKey]
) throws -> UUID {
  let string = try wrapJSONError({ try json.requireString() }, codingPath: codingPath)
  guard let uuid = UUID(uuidString: string) else {
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription: "Invalid UUID string: \(string)"
      )
    )
  }
  return uuid
}

// MARK: - JSONError → DecodingError wrapping

/// Wraps a JSONError thrown by a require*() call into DecodingError.typeMismatch
/// with a coding path that includes the current key.
package func decodeJSON<T>(_ expression: () throws -> T, codingPath: [CodingKey]) throws -> T {
  do {
    return try expression()
  } catch let error as JSONError {
    throw DecodingError.typeMismatch(
      T.self,
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription: String(describing: error)
      )
    )
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
    try valueForKey(key) { json in try decodeJSON({ try json.requireBool() }, codingPath: codingPath + [key]) }
  }

  func decode(_: String.Type, forKey key: Key) throws -> String {
    try valueForKey(key) { json in try decodeJSON({ try json.requireString() }, codingPath: codingPath + [key]) }
  }

  func decode(_: Int64.Type, forKey key: Key) throws -> Int64 {
    try valueForKey(key) { json in try decodeJSON({ try json.requireInt64() }, codingPath: codingPath + [key]) }
  }

  func decode(_: Int.Type, forKey key: Key) throws -> Int {
    try valueForKey(key) { json in try decodeJSON({ try json.requireInt() }, codingPath: codingPath + [key]) }
  }

  func decode(_: Double.Type, forKey key: Key) throws -> Double {
    try valueForKey(key) { json in try decodeJSON({ try json.requireDouble() }, codingPath: codingPath + [key]) }
  }

  func decode(_: Float.Type, forKey key: Key) throws -> Float {
    try valueForKey(key) { json in try decodeJSON({ try json.requireFloat() }, codingPath: codingPath + [key]) }
  }

  // MARK: - Integer and unsigned widths

  func decode(_: Int8.Type, forKey key: Key) throws -> Int8 {
    try valueForKey(key) { json in try decodeJSON({ try json.requireInt8() }, codingPath: codingPath + [key]) }
  }

  func decode(_: Int16.Type, forKey key: Key) throws -> Int16 {
    try valueForKey(key) { json in try decodeJSON({ try json.requireInt16() }, codingPath: codingPath + [key]) }
  }

  func decode(_: Int32.Type, forKey key: Key) throws -> Int32 {
    try valueForKey(key) { json in try decodeJSON({ try json.requireInt32() }, codingPath: codingPath + [key]) }
  }

  func decode(_: UInt.Type, forKey key: Key) throws -> UInt {
    try valueForKey(key) { json in try decodeJSON({ try json.requireUInt() }, codingPath: codingPath + [key]) }
  }

  func decode(_: UInt8.Type, forKey key: Key) throws -> UInt8 {
    try valueForKey(key) { json in try decodeJSON({ try json.requireUInt8() }, codingPath: codingPath + [key]) }
  }

  func decode(_: UInt16.Type, forKey key: Key) throws -> UInt16 {
    try valueForKey(key) { json in try decodeJSON({ try json.requireUInt16() }, codingPath: codingPath + [key]) }
  }

  func decode(_: UInt32.Type, forKey key: Key) throws -> UInt32 {
    try valueForKey(key) { json in try decodeJSON({ try json.requireUInt32() }, codingPath: codingPath + [key]) }
  }

  func decode(_: UInt64.Type, forKey key: Key) throws -> UInt64 {
    try valueForKey(key) { json in try decodeJSON({ try json.requireUInt64() }, codingPath: codingPath + [key]) }
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

// MARK: - Unkeyed decoding container

struct _JSONUnkeyedDecodingContainer: UnkeyedDecodingContainer {
  let codingPath: [CodingKey]
  let count: Int?
  var currentIndex: Int = 0
  var isAtEnd: Bool {
    currentIndex >= (elements.count)
  }

  private let elements: [JSON]
  private let impl: _JSONDecodeImpl

  init(elements: [JSON], impl: _JSONDecodeImpl, pathPrefix: [CodingKey]) {
    self.elements = elements
    self.impl = impl
    codingPath = pathPrefix
    count = elements.count
  }

  mutating func decodeNil() throws -> Bool {
    let value = try currentElement()
    if case .null = value.storage { return true }
    return false
  }

  mutating func decode(_: Bool.Type) throws -> Bool {
    try decodeJSON({ try currentElement().requireBool() }, codingPath: codingPath)
  }

  mutating func decode(_: String.Type) throws -> String {
    try decodeJSON({ try currentElement().requireString() }, codingPath: codingPath)
  }

  mutating func decode(_: Int64.Type) throws -> Int64 {
    try decodeJSON({ try currentElement().requireInt64() }, codingPath: codingPath)
  }

  mutating func decode(_: Int.Type) throws -> Int {
    try decodeJSON({ try currentElement().requireInt() }, codingPath: codingPath)
  }

  mutating func decode(_: Double.Type) throws -> Double {
    try decodeJSON({ try currentElement().requireDouble() }, codingPath: codingPath)
  }

  mutating func decode(_: Float.Type) throws -> Float {
    try decodeJSON({ try currentElement().requireFloat() }, codingPath: codingPath)
  }

  // MARK: - Integer and unsigned widths

  mutating func decode(_: Int8.Type) throws -> Int8 {
    try decodeJSON({ try currentElement().requireInt8() }, codingPath: codingPath)
  }

  mutating func decode(_: Int16.Type) throws -> Int16 {
    try decodeJSON({ try currentElement().requireInt16() }, codingPath: codingPath)
  }

  mutating func decode(_: Int32.Type) throws -> Int32 {
    try decodeJSON({ try currentElement().requireInt32() }, codingPath: codingPath)
  }

  mutating func decode(_: UInt.Type) throws -> UInt {
    try decodeJSON({ try currentElement().requireUInt() }, codingPath: codingPath)
  }

  mutating func decode(_: UInt8.Type) throws -> UInt8 {
    try decodeJSON({ try currentElement().requireUInt8() }, codingPath: codingPath)
  }

  mutating func decode(_: UInt16.Type) throws -> UInt16 {
    try decodeJSON({ try currentElement().requireUInt16() }, codingPath: codingPath)
  }

  mutating func decode(_: UInt32.Type) throws -> UInt32 {
    try decodeJSON({ try currentElement().requireUInt32() }, codingPath: codingPath)
  }

  mutating func decode(_: UInt64.Type) throws -> UInt64 {
    try decodeJSON({ try currentElement().requireUInt64() }, codingPath: codingPath)
  }

  mutating func decode<T: Decodable>(_: T.Type) throws -> T {
    let value = try currentElement()
    // Foundation type special handling
    if T.self == Date.self {
      return try decodeDate(
        from: value, with: impl.dateDecodingStrategy, codingPath: codingPath,
        dateDecodingStrategy: impl.dateDecodingStrategy,
        dataDecodingStrategy: impl.dataDecodingStrategy,
        decimalDecodingStrategy: impl.decimalDecodingStrategy
      )
        as! T
    }
    if T.self == Data.self {
      return try decodeData(
        from: value, with: impl.dataDecodingStrategy, codingPath: codingPath,
        dateDecodingStrategy: impl.dateDecodingStrategy,
        dataDecodingStrategy: impl.dataDecodingStrategy,
        decimalDecodingStrategy: impl.decimalDecodingStrategy
      )
        as! T
    }
    if T.self == URL.self {
      return try decodeURL(from: value, codingPath: codingPath) as! T
    }
    if T.self == UUID.self {
      return try decodeUUID(from: value, codingPath: codingPath) as! T
    }
    if T.self == Decimal.self {
      return try decodeDecimal(
        from: value, with: impl.decimalDecodingStrategy, codingPath: codingPath
      ) as! T
    }
    // Default path
    let child = _JSONDecodeImpl(
      json: value,
      userInfo: impl.userInfo,
      codingPath: codingPath,
      dateDecodingStrategy: impl.dateDecodingStrategy,
      dataDecodingStrategy: impl.dataDecodingStrategy,
      decimalDecodingStrategy: impl.decimalDecodingStrategy
    )
    return try T(from: child)
  }

  mutating func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type
  ) throws -> KeyedDecodingContainer<NestedKey> {
    let value = try currentElement()
    let child = _JSONDecodeImpl(
      json: value,
      userInfo: impl.userInfo,
      codingPath: codingPath,
      dateDecodingStrategy: impl.dateDecodingStrategy,
      dataDecodingStrategy: impl.dataDecodingStrategy,
      decimalDecodingStrategy: impl.decimalDecodingStrategy
    )
    return try child.container(keyedBy: keyType)
  }

  mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
    let value = try currentElement()
    let child = _JSONDecodeImpl(
      json: value,
      userInfo: impl.userInfo,
      codingPath: codingPath,
      dateDecodingStrategy: impl.dateDecodingStrategy,
      dataDecodingStrategy: impl.dataDecodingStrategy,
      decimalDecodingStrategy: impl.decimalDecodingStrategy
    )
    return try child.unkeyedContainer()
  }

  mutating func superDecoder() throws -> Decoder {
    let value = try currentElement()
    return _JSONDecodeImpl(
      json: value,
      userInfo: impl.userInfo,
      codingPath: codingPath,
      dateDecodingStrategy: impl.dateDecodingStrategy,
      dataDecodingStrategy: impl.dataDecodingStrategy,
      decimalDecodingStrategy: impl.decimalDecodingStrategy
    )
  }

  private mutating func currentElement() throws -> JSON {
    guard currentIndex < elements.count else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Array index \(currentIndex) out of bounds"
        )
      )
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
    codingPath = pathPrefix
  }

  func decodeNil() -> Bool {
    if case .null = json.storage { return true }
    return false
  }

  func decode(_: Bool.Type) throws -> Bool {
    try decodeJSON({ try json.requireBool() }, codingPath: codingPath)
  }

  func decode(_: String.Type) throws -> String {
    try decodeJSON({ try json.requireString() }, codingPath: codingPath)
  }

  func decode(_: Int64.Type) throws -> Int64 {
    try decodeJSON({ try json.requireInt64() }, codingPath: codingPath)
  }

  func decode(_: Int.Type) throws -> Int {
    try decodeJSON({ try json.requireInt() }, codingPath: codingPath)
  }

  func decode(_: Double.Type) throws -> Double {
    try decodeJSON({ try json.requireDouble() }, codingPath: codingPath)
  }

  func decode(_: Float.Type) throws -> Float {
    try decodeJSON({ try json.requireFloat() }, codingPath: codingPath)
  }

  // MARK: - Integer and unsigned widths

  func decode(_: Int8.Type) throws -> Int8 {
    try decodeJSON({ try json.requireInt8() }, codingPath: codingPath)
  }

  func decode(_: Int16.Type) throws -> Int16 {
    try decodeJSON({ try json.requireInt16() }, codingPath: codingPath)
  }

  func decode(_: Int32.Type) throws -> Int32 {
    try decodeJSON({ try json.requireInt32() }, codingPath: codingPath)
  }

  func decode(_: UInt.Type) throws -> UInt {
    try decodeJSON({ try json.requireUInt() }, codingPath: codingPath)
  }

  func decode(_: UInt8.Type) throws -> UInt8 {
    try decodeJSON({ try json.requireUInt8() }, codingPath: codingPath)
  }

  func decode(_: UInt16.Type) throws -> UInt16 {
    try decodeJSON({ try json.requireUInt16() }, codingPath: codingPath)
  }

  func decode(_: UInt32.Type) throws -> UInt32 {
    try decodeJSON({ try json.requireUInt32() }, codingPath: codingPath)
  }

  func decode(_: UInt64.Type) throws -> UInt64 {
    try decodeJSON({ try json.requireUInt64() }, codingPath: codingPath)
  }

  func decode<T: Decodable>(_: T.Type) throws -> T {
    // Foundation type special handling
    if T.self == Date.self {
      return try decodeDate(
        from: json, with: impl.dateDecodingStrategy, codingPath: codingPath,
        dateDecodingStrategy: impl.dateDecodingStrategy,
        dataDecodingStrategy: impl.dataDecodingStrategy,
        decimalDecodingStrategy: impl.decimalDecodingStrategy
      )
        as! T
    }
    if T.self == Data.self {
      return try decodeData(
        from: json, with: impl.dataDecodingStrategy, codingPath: codingPath,
        dateDecodingStrategy: impl.dateDecodingStrategy,
        dataDecodingStrategy: impl.dataDecodingStrategy,
        decimalDecodingStrategy: impl.decimalDecodingStrategy
      )
        as! T
    }
    if T.self == URL.self {
      return try decodeURL(from: json, codingPath: codingPath) as! T
    }
    if T.self == UUID.self {
      return try decodeUUID(from: json, codingPath: codingPath) as! T
    }
    if T.self == Decimal.self {
      return try decodeDecimal(
        from: json, with: impl.decimalDecodingStrategy, codingPath: codingPath
      ) as! T
    }
    // Default path
    let child = _JSONDecodeImpl(
      json: json,
      userInfo: impl.userInfo,
      codingPath: codingPath,
      dateDecodingStrategy: impl.dateDecodingStrategy,
      dataDecodingStrategy: impl.dataDecodingStrategy,
      decimalDecodingStrategy: impl.decimalDecodingStrategy
    )
    return try T(from: child)
  }
}
