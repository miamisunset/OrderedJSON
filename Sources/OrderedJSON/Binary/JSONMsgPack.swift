import Foundation
import OrderedCollections

// MARK: - MessagePack binary format

extension JSON {
  /// Decodes MessagePack data into a JSON value.
  ///
  /// MessagePack is a binary serialization format that is more compact
  /// than JSON while preserving type information.
  ///
  /// - Parameter data: The MessagePack-encoded data.
  /// - Returns: A `JSON` value decoded from MessagePack.
  /// - Throws: `JSONError.invalidMsgPack` if the data is malformed.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let decoded = try JSON.fromMsgPack(data)
  /// ```
  public static func fromMsgPack(_ data: Data) throws -> JSON {
    var pos = 0
    let value = try decodeMsgPack(data, &pos)
    if pos < data.count {
      throw JSONError.invalidMsgPack("Trailing bytes after MessagePack value")
    }
    return value
  }

  /// Encodes this JSON value into MessagePack format.
  /// - Returns: MessagePack-encoded data.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let json = JSON.object(["key": .string("value")])
  /// let msgpackData = json.toMsgPack()
  /// ```
  public func toMsgPack() -> Data {
    var bytes: [UInt8] = []
    encodeMsgPack(self, &bytes)
    return Data(bytes)
  }
}

// MARK: - MessagePack decode

private func decodeMsgPack(_ data: Data, _ pos: inout Int) throws -> JSON {
  guard pos < data.count else {
    throw JSONError.invalidMsgPack("Unexpected end of MessagePack data")
  }

  let byte = data[pos]
  pos += 1

  // Positive integer (0x00 - 0x7F)
  if byte <= 0x7F {
    return JSON.number(.integer(Int64(byte)))
  }

  // Negative integer (0xE0 - 0xFF)
  if byte >= 0xE0 {
    return JSON.number(.integer(Int64(Int8(bitPattern: byte))))
  }

  // Map (0x80 - 0x8F)
  if byte >= 0x80 && byte <= 0x8F {
    let count = Int(byte & 0x0F)
    return try decodeMsgPackMap(data, &pos, count)
  }

  // Array (0x90 - 0x9F)
  if byte >= 0x90 && byte <= 0x9F {
    let count = Int(byte & 0x0F)
    return try decodeMsgPackArray(data, &pos, count)
  }

  // String (0xA0 - 0xBF)
  if byte >= 0xA0 && byte <= 0xBF {
    let len = Int(byte & 0x1F)
    return try decodeMsgPackString(data, &pos, len)
  }

  // nil (0xC0)
  if byte == 0xC0 { return JSON.null }
  // false (0xC2)
  if byte == 0xC2 { return JSON.boolean(false) }
  // true (0xC3)
  if byte == 0xC3 { return JSON.boolean(true) }

  // Binary types
  if byte == 0xC4 { return try decodeMsgPackBin(data, &pos, 1) }
  if byte == 0xC5 { return try decodeMsgPackBin(data, &pos, 2) }
  if byte == 0xC6 { return try decodeMsgPackBin(data, &pos, 4) }

  // Float/double
  if byte == 0xCA {
    let bits = readUInt32(data, &pos)
    return JSON.number(.float(Double(Float(bitPattern: bits))))
  }
  if byte == 0xCB {
    let bits = readUInt64(data, &pos)
    return JSON.number(.float(Double(bitPattern: bits)))
  }

  // Unsigned integers
  if byte == 0xCC {
    let v = data[pos]
    pos += 1
    return JSON.number(.integer(Int64(v)))
  }
  if byte == 0xCD { return JSON.number(.integer(Int64(readUInt16(data, &pos)))) }
  if byte == 0xCE { return JSON.number(.integer(Int64(readUInt32(data, &pos)))) }
  if byte == 0xCF {
    let v = readUInt64(data, &pos)
    if v <= UInt64(Int64.max) {
      return JSON.number(.integer(Int64(v)))
    } else {
      return JSON.number(.float(Double(v)))
    }
  }

  // Signed integers
  if byte == 0xD0 {
    let v = Int8(bitPattern: data[pos])
    pos += 1
    return JSON.number(.integer(Int64(v)))
  }
  if byte == 0xD1 {
    let v = Int16(bitPattern: readUInt16(data, &pos))
    return JSON.number(.integer(Int64(v)))
  }
  if byte == 0xD2 {
    let v = Int32(bitPattern: readUInt32(data, &pos))
    return JSON.number(.integer(Int64(v)))
  }
  if byte == 0xD3 { return JSON.number(.integer(readInt64(data, &pos))) }

  // Array 16/32 (0xDC, 0xDD)
  if byte == 0xDC {
    let count = Int(readUInt16(data, &pos))
    return try decodeMsgPackArray(data, &pos, count)
  }
  if byte == 0xDD {
    let count = Int(readUInt32(data, &pos))
    return try decodeMsgPackArray(data, &pos, count)
  }

  // Map 16/32 (0xDE, 0xDF)
  if byte == 0xDE {
    let count = Int(readUInt16(data, &pos))
    return try decodeMsgPackMap(data, &pos, count)
  }
  if byte == 0xDF {
    let count = Int(readUInt32(data, &pos))
    return try decodeMsgPackMap(data, &pos, count)
  }

  // String 8/16/32 (0xD9, 0xDA, 0xDB)
  if byte == 0xD9 {
    let len = Int(data[pos])
    pos += 1
    return try decodeMsgPackString(data, &pos, len)
  }
  if byte == 0xDA {
    let len = Int(readUInt16(data, &pos))
    return try decodeMsgPackString(data, &pos, len)
  }
  if byte == 0xDB {
    let len = Int(readUInt32(data, &pos))
    return try decodeMsgPackString(data, &pos, len)
  }

  throw JSONError.invalidMsgPack("Unknown MessagePack type: \(byte)")
}

private func decodeMsgPackString(_ data: Data, _ pos: inout Int, _ len: Int) throws -> JSON {
  guard len >= 0, pos + len <= data.count else {
    throw JSONError.invalidMsgPack("String length exceeds data")
  }
  let body = data[pos..<pos + len]
  pos += len
  guard let str = String(data: body, encoding: .utf8) else {
    throw JSONError.invalidMsgPack("Invalid UTF-8 string")
  }
  return JSON.string(str)
}

private func decodeMsgPackBin(_ data: Data, _ pos: inout Int, _ sizeLen: Int) throws -> JSON {
  let len: Int
  if sizeLen == 1 {
    len = Int(data[pos])
    pos += 1
  } else if sizeLen == 2 {
    len = Int(readUInt16(data, &pos))
  } else {
    len = Int(readUInt32(data, &pos))
  }
  guard len >= 0, pos + len <= data.count else {
    throw JSONError.invalidMsgPack("Binary length exceeds data")
  }
  let body = data[pos..<pos + len]
  pos += len
  return JSON.string(body.base64EncodedString())
}

private func decodeMsgPackArray(_ data: Data, _ pos: inout Int, _ count: Int) throws -> JSON {
  var elements: [JSON] = []
  for _ in 0..<count {
    try elements.append(decodeMsgPack(data, &pos))
  }
  return JSON.array(elements)
}

private func decodeMsgPackMap(_ data: Data, _ pos: inout Int, _ count: Int) throws -> JSON {
  var dict = OrderedDictionary<String, JSON>()
  for _ in 0..<count {
    let key = try decodeMsgPack(data, &pos)
    guard case .string(let str) = key.storage else {
      throw JSONError.invalidMsgPack("Non-string MessagePack map key")
    }
    dict[str] = try decodeMsgPack(data, &pos)
  }
  return JSON.object(dict)
}

// MARK: - MessagePack encode

private func encodeMsgPack(_ json: JSON, _ bytes: inout [UInt8]) {
  switch json.storage {
  case .null:
    bytes.append(0xC0)

  case .boolean(let value):
    bytes.append(value ? 0xC3 : 0xC2)

  case .number(let num):
    switch num {
    case .integer(let value):
      if value >= 0, value <= 127 {
        bytes.append(UInt8(value))
      } else if value < 0, value >= -32 {
        bytes.append(UInt8(bitPattern: Int8(truncatingIfNeeded: value)))
      } else if value >= 0, value <= 0xFF {
        bytes.append(0xCC)
        bytes.append(UInt8(value))
      } else if value >= 0, value <= 0xFFFF {
        bytes.append(0xCD)
        appendUInt16(UInt16(value), &bytes)
      } else if value >= 0, value <= 0xFFFF_FFFF {
        bytes.append(0xCE)
        appendUInt32(UInt32(value), &bytes)
      } else if value >= 0 {
        bytes.append(0xCF)
        appendUInt64(UInt64(value), &bytes)
      } else if value >= Int64(Int8.min) {
        bytes.append(0xD0)
        bytes.append(UInt8(bitPattern: Int8(truncatingIfNeeded: value)))
      } else if value >= Int64(Int16.min) {
        bytes.append(0xD1)
        appendUInt16(UInt16(bitPattern: Int16(truncatingIfNeeded: value)), &bytes)
      } else if value >= Int64(Int32.min) {
        bytes.append(0xD2)
        appendUInt32(UInt32(bitPattern: Int32(truncatingIfNeeded: value)), &bytes)
      } else {
        bytes.append(0xD3)
        appendUInt64(UInt64(bitPattern: Int64(truncatingIfNeeded: value)), &bytes)
      }

    case .float(let value):
      let double = Double(value)
      let f32 = Float(double)
      if double == Double(f32), !double.isNaN, !double.isInfinite {
        bytes.append(0xCA)
        appendUInt32(f32.bitPattern, &bytes)
      } else {
        bytes.append(0xCB)
        appendUInt64(double.bitPattern, &bytes)
      }
    }

  case .string(let str):
    let utf8 = Data(str.utf8)
    let len = utf8.count
    if len <= 31 {
      bytes.append(0xA0 | UInt8(len))
    } else if len <= 0xFF {
      bytes.append(0xD9)
      bytes.append(UInt8(len))
    } else if len <= 0xFFFF {
      bytes.append(0xDA)
      appendUInt16(UInt16(len), &bytes)
    } else {
      bytes.append(0xDB)
      appendUInt32(UInt32(len), &bytes)
    }
    bytes.append(contentsOf: utf8)

  case .array(let arr):
    let count = arr.count
    if count <= 15 {
      bytes.append(0x90 | UInt8(count))
    } else if count <= 0xFFFF {
      bytes.append(0xDC)
      appendUInt16(UInt16(count), &bytes)
    } else {
      bytes.append(0xDD)
      appendUInt32(UInt32(count), &bytes)
    }
    for element in arr {
      encodeMsgPack(element, &bytes)
    }

  case .object(let dict):
    let count = dict.count
    if count <= 15 {
      bytes.append(0x80 | UInt8(count))
    } else if count <= 0xFFFF {
      bytes.append(0xDE)
      appendUInt16(UInt16(count), &bytes)
    } else {
      bytes.append(0xDF)
      appendUInt32(UInt32(count), &bytes)
    }
    for (key, value) in dict {
      encodeMsgPackString(key, &bytes)
      encodeMsgPack(value, &bytes)
    }
  }
}

private func encodeMsgPackString(_ str: String, _ bytes: inout [UInt8]) {
  let utf8 = Data(str.utf8)
  let len = utf8.count
  if len <= 31 {
    bytes.append(0xA0 | UInt8(len))
  } else if len <= 0xFF {
    bytes.append(0xD9)
    bytes.append(UInt8(len))
  } else if len <= 0xFFFF {
    bytes.append(0xDA)
    appendUInt16(UInt16(len), &bytes)
  } else {
    bytes.append(0xDB)
    appendUInt32(UInt32(len), &bytes)
  }
  bytes.append(contentsOf: utf8)
}

// MARK: - Helpers (shared)

private func readUInt16(_ data: Data, _ pos: inout Int) -> UInt16 {
  let value = UInt16(data[pos]) << 8 | UInt16(data[pos + 1])
  pos += 2
  return value
}

private func readUInt32(_ data: Data, _ pos: inout Int) -> UInt32 {
  let value =
    UInt32(data[pos]) << 24 | UInt32(data[pos + 1]) << 16 | UInt32(data[pos + 2]) << 8
    | UInt32(data[pos + 3])
  pos += 4
  return value
}

private func readUInt64(_ data: Data, _ pos: inout Int) -> UInt64 {
  let value =
    UInt64(data[pos]) << 56 | UInt64(data[pos + 1]) << 48 | UInt64(data[pos + 2]) << 40 | UInt64(
      data[pos + 3]
    ) << 32 | UInt64(data[pos + 4]) << 24 | UInt64(data[pos + 5]) << 16 | UInt64(
      data[pos + 6]
    ) << 8 | UInt64(data[pos + 7])
  pos += 8
  return value
}

private func readInt64(_ data: Data, _ pos: inout Int) -> Int64 {
  return Int64(bitPattern: readUInt64(data, &pos))
}

private func appendUInt16(_ value: UInt16, _ bytes: inout [UInt8]) {
  bytes.append(UInt8(value >> 8))
  bytes.append(UInt8(value & 0xFF))
}

private func appendUInt32(_ value: UInt32, _ bytes: inout [UInt8]) {
  bytes.append(UInt8((value >> 24) & 0xFF))
  bytes.append(UInt8((value >> 16) & 0xFF))
  bytes.append(UInt8((value >> 8) & 0xFF))
  bytes.append(UInt8(value & 0xFF))
}

private func appendUInt64(_ value: UInt64, _ bytes: inout [UInt8]) {
  bytes.append(UInt8((value >> 56) & 0xFF))
  bytes.append(UInt8((value >> 48) & 0xFF))
  bytes.append(UInt8((value >> 40) & 0xFF))
  bytes.append(UInt8((value >> 32) & 0xFF))
  bytes.append(UInt8((value >> 24) & 0xFF))
  bytes.append(UInt8((value >> 16) & 0xFF))
  bytes.append(UInt8((value >> 8) & 0xFF))
  bytes.append(UInt8(value & 0xFF))
}

// MARK: - Error

extension JSONError {
  /// Creates a MessagePack-specific error wrapped in `formatError`.
  /// - Parameter reason: A description of the error.
  /// - Returns: A `JSONError.formatError` with the MessagePack prefix.
  public static func invalidMsgPack(_ reason: String = "") -> JSONError {
    return .formatError("MsgPack: \(reason)")
  }
}
