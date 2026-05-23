import Foundation
import OrderedCollections

// MARK: - BSON binary format

extension JSON {
  /// Decodes BSON data into a JSON value.
  ///
  /// BSON (Binary JSON) is a binary representation of JSON documents used
  /// primarily by MongoDB. This implementation supports the most common
  /// BSON types: double, string, embedded document, array, binary data,
  /// boolean, null, int32, and int64.
  ///
  /// - Parameter data: The BSON-encoded data.
  /// - Returns: A `JSON` value decoded from BSON.
  /// - Throws: `JSONError.invalidBSON` if the data is malformed.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let decoded = try JSON.fromBSON(data)
  /// ```
  public static func fromBSON(_ data: Data) throws -> JSON {
    var pos = 0
    let value = try decodeBSONDocument(data, &pos)
    if pos < data.count {
      throw JSONError.invalidBSON("Trailing bytes after BSON value")
    }
    return value
  }

  /// Encodes this JSON value into BSON format.
  /// - Returns: BSON-encoded data.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let json = JSON.object(["key": .string("value")])
  /// let bsonData = json.toBSON()
  /// ```
  public func toBSON() -> Data {
    var bytes: [UInt8] = []
    // BSON document: placeholder for length, then elements, then null
    let _ = bytes.count
    // Will write length at start
    encodeBSONDocument(self, &bytes)
    // Write total length at start
    let totalLen = UInt32(bytes.count)
    bytes[0] = UInt8(totalLen & 0xFF)
    bytes[1] = UInt8((totalLen >> 8) & 0xFF)
    bytes[2] = UInt8((totalLen >> 16) & 0xFF)
    bytes[3] = UInt8((totalLen >> 24) & 0xFF)
    return Data(bytes)
  }
}

// MARK: - BSON decode

private func decodeBSONDocument(_ data: Data, _ pos: inout Int) throws -> JSON {
  guard pos + 4 <= data.count else {
    throw JSONError.invalidBSON("Unexpected end of BSON document")
  }

  let docLen = Int(readBSONInt32(data, &pos))
  let endPos = pos + docLen - 5  // minus 4 length bytes and 1 null terminator

  var dict = OrderedDictionary<String, JSON>()
  while pos < endPos {
    let (key, value) = try decodeBSONElement(data, &pos)
    dict[key] = value
  }

  // Skip null terminator
  if pos < data.count {
    pos += 1
  }

  return JSON.object(dict)
}

private func decodeBSONElement(_ data: Data, _ pos: inout Int) throws -> (String, JSON) {
  guard pos < data.count else {
    throw JSONError.invalidBSON("Unexpected end of BSON element")
  }

  let type = data[pos]
  pos += 1

  let key = try decodeBSONCString(data, &pos)

  switch type {
  case 0x01:  // Double
    let bits = readBSONUInt64(data, &pos)
    return (key, JSON.number(.float(Double(bitPattern: bits))))

  case 0x02:  // UTF-8 string
    let len = Int(readBSONInt32(data, &pos))
    let body = data[pos..<pos + len - 1]  // -1 for null terminator
    pos += len
    guard let str = String(data: body, encoding: .utf8) else {
      throw JSONError.invalidBSON("Invalid UTF-8 string")
    }
    return (key, JSON.string(str))

  case 0x03:  // Embedded document
    let value = try decodeBSONDocument(data, &pos)
    return (key, value)

  case 0x04:  // Array
    let arr = try decodeBSONArray(data, &pos)
    return (key, arr)

  case 0x05:  // Binary data
    let len = Int(readBSONInt32(data, &pos))
    let _ = data[pos]
    pos += 1
    let body = data[pos..<pos + len]
    pos += len
    return (key, JSON.string(body.base64EncodedString()))

  case 0x08:  // Boolean
    let value = data[pos] != 0
    pos += 1
    return (key, JSON.boolean(value))

  case 0x0A:  // Null
    return (key, JSON.null)

  case 0x10:  // int32
    let value = Int64(readBSONInt32(data, &pos))
    return (key, JSON.number(.integer(value)))

  case 0x12:  // int64
    let value = Int64(bitPattern: readBSONUInt64(data, &pos))
    return (key, JSON.number(.integer(value)))

  default:
    throw JSONError.invalidBSON("Unsupported BSON type: \(type)")
  }
}

private func decodeBSONArray(_ data: Data, _ pos: inout Int) throws -> JSON {
  guard pos + 4 <= data.count else {
    throw JSONError.invalidBSON("Unexpected end of BSON array")
  }

  let docLen = Int(readBSONInt32(data, &pos))
  let endPos = pos + docLen - 1

  var elements: [JSON] = []
  while pos < endPos {
    let (_, value) = try decodeBSONElement(data, &pos)
    elements.append(value)
  }

  // Skip null terminator
  if pos < data.count {
    pos += 1
  }

  return JSON.array(elements)
}

private func decodeBSONCString(_ data: Data, _ pos: inout Int) throws -> String {
  var bytes: [UInt8] = []
  while pos < data.count {
    let ch = data[pos]
    pos += 1
    if ch == 0 { break }
    bytes.append(ch)
  }
  return String(bytes: bytes, encoding: .utf8) ?? ""
}

// MARK: - BSON encode

private func encodeBSONDocument(_ json: JSON, _ bytes: inout [UInt8]) {
  // Write placeholder length (4 bytes)
  let lenPos = bytes.count
  bytes.append(0)
  bytes.append(0)
  bytes.append(0)
  bytes.append(0)

  switch json.storage {
  case .object(let dict):
    for (key, value) in dict {
      encodeBSONElement(key, value, &bytes)
    }

  case .array(let arr):
    for (index, value) in arr.enumerated() {
      let key = "\(index)"
      encodeBSONElement(key, value, &bytes)
    }

  case .string(let str):
    encodeBSONElement("value", JSON.string(str), &bytes)

  case .number(let num):
    encodeBSONElement("value", JSON.number(num), &bytes)

  case .boolean(let value):
    encodeBSONElement("value", JSON.boolean(value), &bytes)

  case .null:
    encodeBSONElement("value", JSON.null, &bytes)
  }

  // Null terminator
  bytes.append(0)

  // Write actual length
  let totalLen = UInt32(bytes.count - lenPos)
  bytes[lenPos] = UInt8(totalLen & 0xFF)
  bytes[lenPos + 1] = UInt8((totalLen >> 8) & 0xFF)
  bytes[lenPos + 2] = UInt8((totalLen >> 16) & 0xFF)
  bytes[lenPos + 3] = UInt8((totalLen >> 24) & 0xFF)
}

private func encodeBSONElement(_ key: String, _ json: JSON, _ bytes: inout [UInt8]) {
  switch json.storage {
  case .null:
    bytes.append(0x0A)  // null
    encodeBSONCString(key, &bytes)

  case .boolean(let value):
    bytes.append(0x08)  // boolean
    encodeBSONCString(key, &bytes)
    bytes.append(value ? 1 : 0)

  case .number(let num):
    switch num {
    case .integer(let value):
      if value >= Int64(Int32.min) && value <= Int64(Int32.max) {
        bytes.append(0x10)  // int32
        encodeBSONCString(key, &bytes)
        appendBSONInt32(Int32(truncatingIfNeeded: value), &bytes)
      } else {
        bytes.append(0x12)  // int64
        encodeBSONCString(key, &bytes)
        appendBSONUInt64(UInt64(bitPattern: value), &bytes)
      }
    case .float(let value):
      bytes.append(0x01)  // double
      encodeBSONCString(key, &bytes)
      appendBSONUInt64(Double(value).bitPattern, &bytes)
    }

  case .string(let str):
    bytes.append(0x02)  // UTF-8 string
    encodeBSONCString(key, &bytes)
    let utf8 = Data(str.utf8)
    appendBSONInt32(Int32(utf8.count + 1), &bytes)  // length includes null terminator
    bytes.append(contentsOf: utf8)
    bytes.append(0)  // null terminator

  case .array:
    bytes.append(0x04)  // array
    encodeBSONCString(key, &bytes)
    let arrBytes = encodeBSONDocumentBytes(json)
    bytes.append(contentsOf: arrBytes)

  case .object:
    bytes.append(0x03)  // embedded document
    encodeBSONCString(key, &bytes)
    let docBytes = encodeBSONDocumentBytes(json)
    bytes.append(contentsOf: docBytes)
  }
}

private func encodeBSONDocumentBytes(_ json: JSON) -> [UInt8] {
  var innerBytes: [UInt8] = []
  encodeBSONDocument(json, &innerBytes)
  return innerBytes
}

private func encodeBSONCString(_ str: String, _ bytes: inout [UInt8]) {
  bytes.append(contentsOf: Data(str.utf8))
  bytes.append(0)
}

// MARK: - BSON helpers (little-endian)

private func readBSONInt32(_ data: Data, _ pos: inout Int) -> Int32 {
  let value = Int32(bitPattern: readBSONUInt32(data, &pos))
  return value
}

private func readBSONUInt32(_ data: Data, _ pos: inout Int) -> UInt32 {
  let value =
    UInt32(data[pos]) | UInt32(data[pos + 1]) << 8 | UInt32(data[pos + 2]) << 16 | UInt32(
      data[pos + 3]) << 24
  pos += 4
  return value
}

private func readBSONUInt64(_ data: Data, _ pos: inout Int) -> UInt64 {
  let value =
    UInt64(data[pos]) | UInt64(data[pos + 1]) << 8 | UInt64(data[pos + 2]) << 16 | UInt64(
      data[pos + 3]) << 24 | UInt64(data[pos + 4]) << 32 | UInt64(data[pos + 5]) << 40 | UInt64(
      data[pos + 6]) << 48 | UInt64(data[pos + 7]) << 56
  pos += 8
  return value
}

private func appendBSONInt32(_ value: Int32, _ bytes: inout [UInt8]) {
  let bits = UInt32(bitPattern: value)
  bytes.append(UInt8(bits & 0xFF))
  bytes.append(UInt8((bits >> 8) & 0xFF))
  bytes.append(UInt8((bits >> 16) & 0xFF))
  bytes.append(UInt8((bits >> 24) & 0xFF))
}

private func appendBSONUInt64(_ value: UInt64, _ bytes: inout [UInt8]) {
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
  /// Creates a BSON-specific error wrapped in `invalidPatch`.
  /// - Parameter reason: A description of the error.
  /// - Returns: A `JSONError.invalidPatch` with the BSON prefix.
  public static func invalidBSON(_ reason: String = "") -> JSONError {
    return .invalidPatch("BSON: \(reason)")
  }
}
