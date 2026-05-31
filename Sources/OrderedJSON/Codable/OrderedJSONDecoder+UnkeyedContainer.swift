import Foundation
import OrderedCollections

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
