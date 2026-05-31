import Foundation

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
