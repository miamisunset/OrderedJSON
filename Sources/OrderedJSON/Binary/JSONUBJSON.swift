import Foundation
import OrderedCollections

// MARK: - UBJSON (Universal Binary JSON) format

extension JSON {
  /// Decodes UBJSON data into a JSON value.
  ///
  /// Universal Binary JSON is a binary JSON format that uses type markers
  /// and little-endian multi-byte integers.
  ///
  /// - Parameter data: The UBJSON-encoded data.
  /// - Returns: A `JSON` value decoded from UBJSON.
  /// - Throws: `JSONError.invalidUBJSON` if the data is malformed.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let decoded = try JSON.fromUBJSON(data)
  /// ```
  public static func fromUBJSON(_ data: Data) throws -> JSON {
    var pos = 0
    let value = try decodeUBJSON(data, &pos)
    if pos < data.count {
      throw JSONError.invalidUBJSON("Trailing bytes after UBJSON value")
    }
    return value
  }

  /// Encodes this JSON value into UBJSON format.
  /// - Returns: UBJSON-encoded data.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let json = JSON.object(["key": .string("value")])
  /// let ubjsonData = json.toUBJSON()
  /// ```
  public func toUBJSON() -> Data {
    var bytes: [UInt8] = []
    encodeUBJSON(self, &bytes)
    return Data(bytes)
  }
}

// MARK: - UBJSON decode

private let ubjsonMarkerNull: UInt8 = 0x5A  // 'Z'
private let ubjsonMarkerTrue: UInt8 = 0x54  // 'T'
private let ubjsonMarkerFalse: UInt8 = 0x46  // 'F'
private let ubjsonMarkerInt8: UInt8 = 0x49  // 'I'
private let ubjsonMarkerInt16: UInt8 = 0x69  // 'i'
private let ubjsonMarkerInt32: UInt8 = 0x6C  // 'l'
private let ubjsonMarkerInt64: UInt8 = 0x4C  // 'L'
private let ubjsonMarkerFloat32: UInt8 = 0x64  // 'd'
private let ubjsonMarkerFloat64: UInt8 = 0x44  // 'D'
private let ubjsonMarkerChar: UInt8 = 0x43  // 'C'
private let ubjsonMarkerString: UInt8 = 0x53  // 'S'
private let ubjsonMarkerArray: UInt8 = 0x5B  // '['
private let ubjsonMarkerObject: UInt8 = 0x7B  // '{'

private func decodeUBJSON(_ data: Data, _ pos: inout Int) throws -> JSON {
  guard pos < data.count else {
    throw JSONError.invalidUBJSON("Unexpected end of UBJSON data")
  }

  let marker = data[pos]
  pos += 1

  switch marker {
  case ubjsonMarkerNull:
    return JSON.null

  case ubjsonMarkerTrue:
    return JSON.boolean(true)

  case ubjsonMarkerFalse:
    return JSON.boolean(false)

  case ubjsonMarkerInt8:
    guard pos < data.count else { throw JSONError.invalidUBJSON("Unexpected end") }
    let value = Int64(Int8(bitPattern: data[pos]))
    pos += 1
    return JSON.number(.integer(value))

  case ubjsonMarkerInt16:
    let value = Int64(Int16(bitPattern: try readUBJSONUInt16(data, &pos)))
    return JSON.number(.integer(value))

  case ubjsonMarkerInt32:
    let value = Int64(Int32(bitPattern: try readUBJSONUInt32(data, &pos)))
    return JSON.number(.integer(value))

  case ubjsonMarkerInt64:
    let value = Int64(bitPattern: try readUBJSONUInt64(data, &pos))
    return JSON.number(.integer(value))

  case ubjsonMarkerFloat32:
    let value = Double(Float(bitPattern: try readUBJSONUInt32(data, &pos)))
    return JSON.number(.float(value))

  case ubjsonMarkerFloat64:
    let value = Double(bitPattern: try readUBJSONUInt64(data, &pos))
    return JSON.number(.float(value))

  case ubjsonMarkerChar:
    guard pos < data.count else { throw JSONError.invalidUBJSON("Unexpected end") }
    let str = String(UnicodeScalar(data[pos]))
    pos += 1
    return JSON.string(str)

  case ubjsonMarkerString:
    let len = try decodeUBJSONStringLen(data, &pos)
    guard len >= 0, pos + len <= data.count else {
      throw JSONError.invalidUBJSON("String length exceeds data")
    }
    let body = data[pos..<pos + len]
    pos += len
    guard let str = String(data: body, encoding: .utf8) else {
      throw JSONError.invalidUBJSON("Invalid UTF-8 string")
    }
    return JSON.string(str)

  case ubjsonMarkerArray:
    let count = try decodeUBJSONCount(data, &pos)
    var elements: [JSON] = []
    for _ in 0..<count {
      elements.append(try decodeUBJSON(data, &pos))
    }
    return JSON.array(elements)

  case ubjsonMarkerObject:
    let count = try decodeUBJSONCount(data, &pos)
    var dict = OrderedDictionary<String, JSON>()
    for _ in 0..<count {
      let key = try decodeUBJSONString(data, &pos)
      dict[key] = try decodeUBJSON(data, &pos)
    }
    return JSON.object(dict)

  default:
    throw JSONError.invalidUBJSON("Unknown UBJSON marker: \(marker)")
  }
}

private func decodeUBJSONStringLen(_ data: Data, _ pos: inout Int) throws -> Int {
  guard pos < data.count else { throw JSONError.invalidUBJSON("Unexpected end") }
  let marker = data[pos]
  pos += 1

  switch marker {
  case ubjsonMarkerInt8:
    guard pos < data.count else { throw JSONError.invalidUBJSON("Unexpected end") }
    let len = Int(Int8(bitPattern: data[pos]))
    pos += 1
    guard len >= 0 else { throw JSONError.invalidUBJSON("Negative string length") }
    return len
  case ubjsonMarkerInt16:
    let len = Int(Int16(bitPattern: try readUBJSONUInt16(data, &pos)))
    guard len >= 0 else { throw JSONError.invalidUBJSON("Negative string length") }
    return len
  case ubjsonMarkerInt32:
    let len = Int(Int32(bitPattern: try readUBJSONUInt32(data, &pos)))
    guard len >= 0 else { throw JSONError.invalidUBJSON("Negative string length") }
    return len
  default:
    throw JSONError.invalidUBJSON("Expected integer marker for string length")
  }
}

private func decodeUBJSONCount(_ data: Data, _ pos: inout Int) throws -> Int {
  guard pos < data.count else { throw JSONError.invalidUBJSON("Unexpected end") }
  let marker = data[pos]
  pos += 1

  switch marker {
  case ubjsonMarkerInt8:
    guard pos < data.count else { throw JSONError.invalidUBJSON("Unexpected end") }
    let count = Int(Int8(bitPattern: data[pos]))
    pos += 1
    guard count >= 0 else { throw JSONError.invalidUBJSON("Negative container count") }
    return count
  case ubjsonMarkerInt16:
    let count = Int(Int16(bitPattern: try readUBJSONUInt16(data, &pos)))
    guard count >= 0 else { throw JSONError.invalidUBJSON("Negative container count") }
    return count
  case ubjsonMarkerInt32:
    let count = Int(Int32(bitPattern: try readUBJSONUInt32(data, &pos)))
    guard count >= 0 else { throw JSONError.invalidUBJSON("Negative container count") }
    return count
  default:
    throw JSONError.invalidUBJSON("Expected integer marker for container count")
  }
}

private func decodeUBJSONString(_ data: Data, _ pos: inout Int) throws -> String {
  // Expect a string value (marker + length + data)
  guard pos < data.count else { throw JSONError.invalidUBJSON("Unexpected end") }
  let marker = data[pos]
  pos += 1

  if marker == ubjsonMarkerString {
    let len = try decodeUBJSONStringLen(data, &pos)
    guard len >= 0, pos + len <= data.count else {
      throw JSONError.invalidUBJSON("String length exceeds data")
    }
    let body = data[pos..<pos + len]
    pos += len
    guard let str = String(data: body, encoding: .utf8) else {
      throw JSONError.invalidUBJSON("Invalid UTF-8 string")
    }
    return str
  }

  if marker == ubjsonMarkerChar {
    guard pos < data.count else { throw JSONError.invalidUBJSON("Unexpected end") }
    let str = String(UnicodeScalar(data[pos]))
    pos += 1
    return str
  }

  throw JSONError.invalidUBJSON("Expected string marker for object key")
}

// MARK: - UBJSON encode

private func encodeUBJSON(_ json: JSON, _ bytes: inout [UInt8]) {
  switch json.storage {
  case .null:
    bytes.append(ubjsonMarkerNull)

  case .boolean(let value):
    bytes.append(value ? ubjsonMarkerTrue : ubjsonMarkerFalse)

  case .number(let num):
    switch num {
    case .integer(let value):
      if value >= Int64(Int8.min) && value <= Int64(Int8.max) {
        bytes.append(ubjsonMarkerInt8)
        bytes.append(UInt8(bitPattern: Int8(truncatingIfNeeded: value)))
      } else if value >= Int64(Int16.min) && value <= Int64(Int16.max) {
        bytes.append(ubjsonMarkerInt16)
        appendUBJSONUInt16(UInt16(bitPattern: Int16(truncatingIfNeeded: value)), &bytes)
      } else if value >= Int64(Int32.min) && value <= Int64(Int32.max) {
        bytes.append(ubjsonMarkerInt32)
        appendUBJSONUInt32(UInt32(bitPattern: Int32(truncatingIfNeeded: value)), &bytes)
      } else {
        bytes.append(ubjsonMarkerInt64)
        appendUBJSONUInt64(UInt64(bitPattern: Int64(truncatingIfNeeded: value)), &bytes)
      }

    case .float(let value):
      let double = Double(value)
      let f32 = Float(double)
      if double == Double(f32) && !double.isNaN && !double.isInfinite {
        bytes.append(ubjsonMarkerFloat32)
        appendUBJSONUInt32(f32.bitPattern, &bytes)
      } else {
        bytes.append(ubjsonMarkerFloat64)
        appendUBJSONUInt64(double.bitPattern, &bytes)
      }
    }

  case .string(let str):
    let utf8 = Data(str.utf8)
    let len = utf8.count
    if len == 1 && str.count == 1 {
      bytes.append(ubjsonMarkerChar)
      bytes.append(contentsOf: utf8)
    } else {
      bytes.append(ubjsonMarkerString)
      encodeUBJSONInt(len, &bytes)
      bytes.append(contentsOf: utf8)
    }

  case .array(let arr):
    bytes.append(ubjsonMarkerArray)
    encodeUBJSONInt(arr.count, &bytes)
    for element in arr {
      encodeUBJSON(element, &bytes)
    }

  case .object(let dict):
    bytes.append(ubjsonMarkerObject)
    encodeUBJSONInt(dict.count, &bytes)
    for (key, value) in dict {
      encodeUBJSONString(key, &bytes)
      encodeUBJSON(value, &bytes)
    }
  }
}

private func encodeUBJSONInt(_ value: Int, _ bytes: inout [UInt8]) {
  if value >= Int(Int8.min) && value <= Int(Int8.max) {
    bytes.append(ubjsonMarkerInt8)
    bytes.append(UInt8(bitPattern: Int8(truncatingIfNeeded: value)))
  } else if value >= Int(Int16.min) && value <= Int(Int16.max) {
    bytes.append(ubjsonMarkerInt16)
    appendUBJSONUInt16(UInt16(bitPattern: Int16(truncatingIfNeeded: value)), &bytes)
  } else {
    bytes.append(ubjsonMarkerInt32)
    appendUBJSONUInt32(UInt32(bitPattern: Int32(truncatingIfNeeded: value)), &bytes)
  }
}

private func encodeUBJSONString(_ str: String, _ bytes: inout [UInt8]) {
  let utf8 = Data(str.utf8)
  let len = utf8.count
  if len == 1 && str.count == 1 {
    bytes.append(ubjsonMarkerChar)
    bytes.append(contentsOf: utf8)
  } else {
    bytes.append(ubjsonMarkerString)
    encodeUBJSONInt(len, &bytes)
    bytes.append(contentsOf: utf8)
  }
}

// MARK: - UBJSON helpers (little-endian)

private func readUBJSONUInt16(_ data: Data, _ pos: inout Int) throws -> UInt16 {
  guard pos + 2 <= data.count else {
    throw JSONError.invalidUBJSON("Unexpected end of UBJSON data")
  }
  // UBJSON uses little-endian for multi-byte integers
  let value = UInt16(data[pos]) | UInt16(data[pos + 1]) << 8
  pos += 2
  return value
}

private func readUBJSONUInt32(_ data: Data, _ pos: inout Int) throws -> UInt32 {
  guard pos + 4 <= data.count else {
    throw JSONError.invalidUBJSON("Unexpected end of UBJSON data")
  }
  let value =
    UInt32(data[pos]) | UInt32(data[pos + 1]) << 8 | UInt32(data[pos + 2]) << 16 | UInt32(
      data[pos + 3]) << 24
  pos += 4
  return value
}

private func readUBJSONUInt64(_ data: Data, _ pos: inout Int) throws -> UInt64 {
  guard pos + 8 <= data.count else {
    throw JSONError.invalidUBJSON("Unexpected end of UBJSON data")
  }
  let value =
    UInt64(data[pos]) | UInt64(data[pos + 1]) << 8 | UInt64(data[pos + 2]) << 16 | UInt64(
      data[pos + 3]) << 24 | UInt64(data[pos + 4]) << 32 | UInt64(data[pos + 5]) << 40 | UInt64(
      data[pos + 6]) << 48 | UInt64(data[pos + 7]) << 56
  pos += 8
  return value
}

private func appendUBJSONUInt16(_ value: UInt16, _ bytes: inout [UInt8]) {
  bytes.append(UInt8(value & 0xFF))
  bytes.append(UInt8(value >> 8))
}

private func appendUBJSONUInt32(_ value: UInt32, _ bytes: inout [UInt8]) {
  bytes.append(UInt8(value & 0xFF))
  bytes.append(UInt8((value >> 8) & 0xFF))
  bytes.append(UInt8((value >> 16) & 0xFF))
  bytes.append(UInt8((value >> 24) & 0xFF))
}

private func appendUBJSONUInt64(_ value: UInt64, _ bytes: inout [UInt8]) {
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
  /// Creates a UBJSON-specific error wrapped in `invalidPatch`.
  /// - Parameter reason: A description of the error.
  /// - Returns: A `JSONError.invalidPatch` with the UBJSON prefix.
  public static func invalidUBJSON(_ reason: String = "") -> JSONError {
    return .invalidPatch("UBJSON: \(reason)")
  }
}
