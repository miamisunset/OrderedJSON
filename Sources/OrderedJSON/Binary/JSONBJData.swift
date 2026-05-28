import Foundation
import OrderedCollections

// MARK: - BJData binary format

extension JSON {
  /// Decodes BJData into a JSON value.
  ///
  /// BJData is a binary JSON format that extends UBJSON with unsigned integer
  /// types, end markers for arrays/objects, and optimized integer encoding.
  /// This implementation supports all BJData marker types including
  /// unsigned integers (UInt8-UInt64) and end-of-array/object markers.
  ///
  /// - Parameter data: The BJData-encoded data.
  /// - Returns: A `JSON` value decoded from BJData.
  /// - Throws: `JSONError.invalidBJData` if the data is malformed.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let decoded = try JSON.fromBJData(data)
  /// ```
  public static func fromBJData(_ data: Data) throws -> JSON {
    var pos = 0
    let value = try decodeBJData(data, &pos)
    if pos < data.count {
      throw JSONError.invalidBJData("Trailing bytes after BJData value")
    }
    return value
  }

  /// Encodes this JSON value into BJData format.
  /// - Returns: BJData-encoded data.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let json = JSON.object(["key": .string("value")])
  /// let bjdataData = json.toBJData()
  /// ```
  public func toBJData() -> Data {
    var bytes: [UInt8] = []
    encodeBJData(self, &bytes)
    return Data(bytes)
  }
}

// MARK: - BJData decode

private let bjdataMarkerNull: UInt8 = 0x5A  // 'Z'
private let bjdataMarkerTrue: UInt8 = 0x54  // 'T'
private let bjdataMarkerFalse: UInt8 = 0x46  // 'F'
private let bjdataMarkerInt8: UInt8 = 0x49  // 'I'
private let bjdataMarkerInt16: UInt8 = 0x69  // 'i'
private let bjdataMarkerInt32: UInt8 = 0x6C  // 'l'
private let bjdataMarkerInt64: UInt8 = 0x4C  // 'L'
private let bjdataMarkerUInt8: UInt8 = 0x55  // 'U'
private let bjdataMarkerUInt16: UInt8 = 0x75  // 'u'
private let bjdataMarkerUInt32: UInt8 = 0x6D  // 'm'
private let bjdataMarkerUInt64: UInt8 = 0x4D  // 'M'
private let bjdataMarkerFloat32: UInt8 = 0x64  // 'd'
private let bjdataMarkerFloat64: UInt8 = 0x44  // 'D'
private let bjdataMarkerChar: UInt8 = 0x43  // 'C'
private let bjdataMarkerString: UInt8 = 0x53  // 'S'
private let bjdataMarkerArray: UInt8 = 0x5B  // '['
private let bjdataMarkerObject: UInt8 = 0x7B  // '{'
private let bjdataMarkerEndArray: UInt8 = 0x5D  // ']'
private let bjdataMarkerEndObject: UInt8 = 0x7D  // '}'

private func decodeBJData(_ data: Data, _ pos: inout Int) throws -> JSON {
  guard pos < data.count else {
    throw JSONError.invalidBJData("Unexpected end of BJData data")
  }

  let marker = data[pos]
  pos += 1

  switch marker {
  case bjdataMarkerNull:
    return JSON.null

  case bjdataMarkerTrue:
    return JSON.boolean(true)

  case bjdataMarkerFalse:
    return JSON.boolean(false)

  case bjdataMarkerInt8:
    guard pos < data.count else { throw JSONError.invalidBJData("Unexpected end") }
    let value = Int64(Int8(bitPattern: data[pos]))
    pos += 1
    return JSON.number(.integer(value))

  case bjdataMarkerInt16:
    let value = try Int64(Int16(bitPattern: readBJDataUInt16(data, &pos)))
    return JSON.number(.integer(value))

  case bjdataMarkerInt32:
    let value = try Int64(Int32(bitPattern: readBJDataUInt32(data, &pos)))
    return JSON.number(.integer(value))

  case bjdataMarkerInt64:
    let value = try Int64(bitPattern: readBJDataUInt64(data, &pos))
    return JSON.number(.integer(value))

  case bjdataMarkerUInt8:
    guard pos < data.count else { throw JSONError.invalidBJData("Unexpected end") }
    let value = Int64(data[pos])
    pos += 1
    return JSON.number(.integer(value))

  case bjdataMarkerUInt16:
    return try JSON.number(.integer(Int64(readBJDataUInt16(data, &pos))))

  case bjdataMarkerUInt32:
    return try JSON.number(.integer(Int64(readBJDataUInt32(data, &pos))))

  case bjdataMarkerUInt64:
    return try JSON.number(.integer(Int64(bitPattern: readBJDataUInt64(data, &pos))))

  case bjdataMarkerFloat32:
    let value = try Double(Float(bitPattern: readBJDataUInt32(data, &pos)))
    return JSON.number(.float(value))

  case bjdataMarkerFloat64:
    let value = try Double(bitPattern: readBJDataUInt64(data, &pos))
    return JSON.number(.float(value))

  case bjdataMarkerChar:
    guard pos < data.count else { throw JSONError.invalidBJData("Unexpected end") }
    let str = String(UnicodeScalar(data[pos]))
    pos += 1
    return JSON.string(str)

  case bjdataMarkerString:
    let len = try decodeBJDataStringLen(data, &pos)
    guard len >= 0, pos + len <= data.count else {
      throw JSONError.invalidBJData("String length exceeds data")
    }
    let body = data[pos..<pos + len]
    pos += len
    guard let str = String(data: body, encoding: .utf8) else {
      throw JSONError.invalidBJData("Invalid UTF-8 string")
    }
    return JSON.string(str)

  case bjdataMarkerArray:
    var elements: [JSON] = []
    while pos < data.count {
      let next = data[pos]
      if next == bjdataMarkerEndArray {
        pos += 1
        break
      }
      try elements.append(decodeBJData(data, &pos))
    }
    return JSON.array(elements)

  case bjdataMarkerObject:
    var dict = OrderedDictionary<String, JSON>()
    while pos < data.count {
      let next = data[pos]
      if next == bjdataMarkerEndObject {
        pos += 1
        break
      }
      let key = try decodeBJDataString(data, &pos)
      dict[key] = try decodeBJData(data, &pos)
    }
    return JSON.object(dict)

  default:
    throw JSONError.invalidBJData("Unknown BJData marker: \(marker)")
  }
}

private func decodeBJDataStringLen(_ data: Data, _ pos: inout Int) throws -> Int {
  guard pos < data.count else { throw JSONError.invalidBJData("Unexpected end") }
  let marker = data[pos]
  pos += 1

  switch marker {
  case bjdataMarkerInt8:
    guard pos < data.count else { throw JSONError.invalidBJData("Unexpected end") }
    let len = Int(Int8(bitPattern: data[pos]))
    pos += 1
    guard len >= 0 else { throw JSONError.invalidBJData("Negative string length") }
    return len
  case bjdataMarkerUInt8:
    guard pos < data.count else { throw JSONError.invalidBJData("Unexpected end") }
    let len = Int(data[pos])
    pos += 1
    return len
  case bjdataMarkerInt16:
    let len = try Int(Int16(bitPattern: readBJDataUInt16(data, &pos)))
    guard len >= 0 else { throw JSONError.invalidBJData("Negative string length") }
    return len
  case bjdataMarkerInt32:
    let len = try Int(Int32(bitPattern: readBJDataUInt32(data, &pos)))
    guard len >= 0 else { throw JSONError.invalidBJData("Negative string length") }
    return len
  default:
    throw JSONError.invalidBJData("Expected integer marker for string length")
  }
}

private func decodeBJDataString(_ data: Data, _ pos: inout Int) throws -> String {
  guard pos < data.count else { throw JSONError.invalidBJData("Unexpected end") }
  let marker = data[pos]
  pos += 1

  if marker == bjdataMarkerString {
    let len = try decodeBJDataStringLen(data, &pos)
    guard len >= 0, pos + len <= data.count else {
      throw JSONError.invalidBJData("String length exceeds data")
    }
    let body = data[pos..<pos + len]
    pos += len
    guard let str = String(data: body, encoding: .utf8) else {
      throw JSONError.invalidBJData("Invalid UTF-8 string")
    }
    return str
  }

  if marker == bjdataMarkerChar {
    guard pos < data.count else { throw JSONError.invalidBJData("Unexpected end") }
    let str = String(UnicodeScalar(data[pos]))
    pos += 1
    return str
  }

  throw JSONError.invalidBJData("Expected string marker for object key")
}

// MARK: - BJData encode

private func encodeBJData(_ json: JSON, _ bytes: inout [UInt8]) {
  switch json.storage {
  case .null:
    bytes.append(bjdataMarkerNull)

  case .boolean(let value):
    bytes.append(value ? bjdataMarkerTrue : bjdataMarkerFalse)

  case .number(let num):
    switch num {
    case .integer(let value):
      if value >= 0, value <= 255 {
        bytes.append(bjdataMarkerUInt8)
        bytes.append(UInt8(value))
      } else if value >= Int64(Int8.min), value <= Int64(Int8.max) {
        bytes.append(bjdataMarkerInt8)
        bytes.append(UInt8(bitPattern: Int8(truncatingIfNeeded: value)))
      } else if value >= 0, value <= Int64(UInt16.max) {
        bytes.append(bjdataMarkerUInt16)
        appendBJDataUInt16(UInt16(value), &bytes)
      } else if value >= Int64(Int16.min), value <= Int64(Int16.max) {
        bytes.append(bjdataMarkerInt16)
        appendBJDataUInt16(UInt16(bitPattern: Int16(truncatingIfNeeded: value)), &bytes)
      } else if value >= 0, value <= Int64(UInt32.max) {
        bytes.append(bjdataMarkerUInt32)
        appendBJDataUInt32(UInt32(value), &bytes)
      } else if value >= Int64(Int32.min), value <= Int64(Int32.max) {
        bytes.append(bjdataMarkerInt32)
        appendBJDataUInt32(UInt32(bitPattern: Int32(truncatingIfNeeded: value)), &bytes)
      } else if value >= 0 {
        bytes.append(bjdataMarkerUInt64)
        appendBJDataUInt64(UInt64(value), &bytes)
      } else {
        bytes.append(bjdataMarkerInt64)
        appendBJDataUInt64(UInt64(bitPattern: value), &bytes)
      }

    case .float(let value):
      let double = Double(value)
      let f32 = Float(double)
      if double == Double(f32), !double.isNaN, !double.isInfinite {
        bytes.append(bjdataMarkerFloat32)
        appendBJDataUInt32(f32.bitPattern, &bytes)
      } else {
        bytes.append(bjdataMarkerFloat64)
        appendBJDataUInt64(double.bitPattern, &bytes)
      }
    }

  case .string(let str):
    let utf8 = Data(str.utf8)
    let len = utf8.count
    if len == 1, str.count == 1 {
      bytes.append(bjdataMarkerChar)
      bytes.append(contentsOf: utf8)
    } else {
      bytes.append(bjdataMarkerString)
      encodeBJDataInt(len, &bytes)
      bytes.append(contentsOf: utf8)
    }

  case .array(let arr):
    bytes.append(bjdataMarkerArray)
    for element in arr {
      encodeBJData(element, &bytes)
    }
    bytes.append(bjdataMarkerEndArray)

  case .object(let dict):
    bytes.append(bjdataMarkerObject)
    for (key, value) in dict {
      encodeBJDataString(key, &bytes)
      encodeBJData(value, &bytes)
    }
    bytes.append(bjdataMarkerEndObject)
  }
}

private func encodeBJDataInt(_ value: Int, _ bytes: inout [UInt8]) {
  if value >= 0, value <= 255 {
    bytes.append(bjdataMarkerUInt8)
    bytes.append(UInt8(value))
  } else if value >= Int(Int16.min), value <= Int(Int16.max) {
    bytes.append(bjdataMarkerInt16)
    appendBJDataUInt16(UInt16(bitPattern: Int16(truncatingIfNeeded: value)), &bytes)
  } else {
    bytes.append(bjdataMarkerInt32)
    appendBJDataUInt32(UInt32(bitPattern: Int32(truncatingIfNeeded: value)), &bytes)
  }
}

private func encodeBJDataString(_ str: String, _ bytes: inout [UInt8]) {
  let utf8 = Data(str.utf8)
  let len = utf8.count
  if len == 1, str.count == 1 {
    bytes.append(bjdataMarkerChar)
    bytes.append(contentsOf: utf8)
  } else {
    bytes.append(bjdataMarkerString)
    encodeBJDataInt(len, &bytes)
    bytes.append(contentsOf: utf8)
  }
}

// MARK: - BJData helpers (little-endian)

private func readBJDataUInt16(_ data: Data, _ pos: inout Int) throws -> UInt16 {
  guard pos + 2 <= data.count else {
    throw JSONError.invalidBJData("Unexpected end of BJData data")
  }
  let value = UInt16(data[pos]) | UInt16(data[pos + 1]) << 8
  pos += 2
  return value
}

private func readBJDataUInt32(_ data: Data, _ pos: inout Int) throws -> UInt32 {
  guard pos + 4 <= data.count else {
    throw JSONError.invalidBJData("Unexpected end of BJData data")
  }
  let value =
    UInt32(data[pos]) | UInt32(data[pos + 1]) << 8 | UInt32(data[pos + 2]) << 16 | UInt32(
      data[pos + 3]
    ) << 24
  pos += 4
  return value
}

private func readBJDataUInt64(_ data: Data, _ pos: inout Int) throws -> UInt64 {
  guard pos + 8 <= data.count else {
    throw JSONError.invalidBJData("Unexpected end of BJData data")
  }
  let value =
    UInt64(data[pos]) | UInt64(data[pos + 1]) << 8 | UInt64(data[pos + 2]) << 16 | UInt64(
      data[pos + 3]
    ) << 24 | UInt64(data[pos + 4]) << 32 | UInt64(data[pos + 5]) << 40 | UInt64(
      data[pos + 6]
    ) << 48 | UInt64(data[pos + 7]) << 56
  pos += 8
  return value
}

private func appendBJDataUInt16(_ value: UInt16, _ bytes: inout [UInt8]) {
  bytes.append(UInt8(value & 0xFF))
  bytes.append(UInt8(value >> 8))
}

private func appendBJDataUInt32(_ value: UInt32, _ bytes: inout [UInt8]) {
  bytes.append(UInt8(value & 0xFF))
  bytes.append(UInt8((value >> 8) & 0xFF))
  bytes.append(UInt8((value >> 16) & 0xFF))
  bytes.append(UInt8((value >> 24) & 0xFF))
}

private func appendBJDataUInt64(_ value: UInt64, _ bytes: inout [UInt8]) {
  bytes.append(UInt8(value & 0xFF))
  bytes.append(UInt8((value >> 8) & 0xFF))
  bytes.append(UInt8((value >> 16) & 0xFF))
  bytes.append(UInt8((value >> 24) & 0xFF))
  bytes.append(UInt8((value >> 32) & 0xFF))
  bytes.append(UInt8((value >> 40) & 0xFF))
  bytes.append(UInt8((value >> 48) & 0xFF))
  bytes.append(UInt8((value >> 56) & 0xFF))
}

// MARK: - Error

extension JSONError {
  /// Creates a BJData-specific error wrapped in `formatError`.
  /// - Parameter reason: A description of the error.
  /// - Returns: A `JSONError.formatError` with the BJData prefix.
  public static func invalidBJData(_ reason: String = "") -> JSONError {
    return .formatError("BJData: \(reason)")
  }
}
