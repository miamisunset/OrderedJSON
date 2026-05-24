import Foundation
import OrderedCollections

// MARK: - CBOR (RFC 7049) binary format

extension JSON {
  /// Decodes CBOR data into a JSON value.
  ///
  /// CBOR (Concise Binary Object Representation) is a binary JSON format
  /// designed for small code size and minimal message size.
  ///
  /// - Parameter data: The CBOR-encoded data.
  /// - Returns: A `JSON` value decoded from CBOR.
  /// - Throws: `JSONError.invalidCBOR` if the data is malformed.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let decoded = try JSON.fromCBOR(data)
  /// ```
  public static func fromCBOR(_ data: Data) throws -> JSON {
    var pos = 0
    let value = try decodeCBOR(data, &pos)
    if pos < data.count {
      throw JSONError.invalidCBOR("Trailing bytes after CBOR value")
    }
    return value
  }

  /// Encodes this JSON value into CBOR format.
  /// - Returns: CBOR-encoded data.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let json = JSON.object(["key": .string("value")])
  /// let cborData = json.toCBOR()
  /// ```
  public func toCBOR() -> Data {
    var bytes: [UInt8] = []
    encodeCBOR(self, &bytes)
    return Data(bytes)
  }
}

// MARK: - CBOR decode

private func decodeCBOR(_ data: Data, _ pos: inout Int) throws -> JSON {
  guard pos < data.count else {
    throw JSONError.invalidCBOR("Unexpected end of CBOR data")
  }

  let byte = data[pos]
  pos += 1

  let majorType = byte >> 5
  let additionalInfo = Int(byte & 0x1F)

  // Handle additional info to get the argument value
  let argument = try readCBORArgument(data, &pos, additionalInfo)

  switch majorType {
  case 0:  // Unsigned integer (positive)
    if argument <= UInt64(Int64.max) {
      return JSON.number(.integer(Int64(argument)))
    } else {
      return JSON.number(.float(Double(argument)))
    }

  case 1:  // Negative integer
    // -1 - argument (negative integers are encoded as -1-n)
    if argument <= UInt64(Int64.max) {
      let value = -1 - Int64(argument)
      return JSON.number(.integer(value))
    } else {
      return JSON.number(.float(-1.0 - Double(argument)))
    }

  case 2:  // Byte string
    let len = Int(argument)
    let body = data[pos..<pos + len]
    pos += len
    return JSON.string(body.base64EncodedString())

  case 3:  // Text string
    let len = Int(argument)
    let body = data[pos..<pos + len]
    pos += len
    guard let str = String(data: body, encoding: .utf8) else {
      throw JSONError.invalidCBOR("Invalid UTF-8 string")
    }
    return JSON.string(str)

  case 4:  // Array
    var elements: [JSON] = []
    for _ in 0..<Int(argument) {
      elements.append(try decodeCBOR(data, &pos))
    }
    return JSON.array(elements)

  case 5:  // Map
    var dict = OrderedDictionary<String, JSON>()
    for _ in 0..<Int(argument) {
      let key = try decodeCBOR(data, &pos)
      guard case .string(let str) = key.storage else {
        throw JSONError.invalidCBOR("Non-string CBOR map key")
      }
      let value = try decodeCBOR(data, &pos)
      dict[str] = value
    }
    return JSON.object(dict)

  case 6:  // Tag — skip tag and decode next value
    return try decodeCBOR(data, &pos)

  case 7:  // Float and simple values
    switch additionalInfo {
    case 20: return JSON.boolean(false)
    case 21: return JSON.boolean(true)
    case 22: return JSON.null
    case 23: return JSON.null  // undefined mapped to null
    case 25:  // half-precision float (2 bytes)
      return JSON.number(.float(halfToFloat(UInt16(argument))))
    case 26:  // single-precision float (4 bytes)
      let bits = UInt32(argument)
      return JSON.number(.float(Double(Float(bitPattern: bits))))
    case 27:  // double-precision float (8 bytes)
      return JSON.number(.float(Double(bitPattern: argument)))
    default:
      throw JSONError.invalidCBOR("Unsupported simple value")
    }

  default:
    throw JSONError.invalidCBOR("Unknown CBOR major type")
  }
}

private func readCBORArgument(_ data: Data, _ pos: inout Int, _ info: Int) throws -> UInt64 {
  if info < 24 {
    return UInt64(info)
  }

  switch info {
  case 24:  // 1 byte
    guard pos < data.count else { throw JSONError.invalidCBOR("Unexpected end of CBOR data") }
    let v = UInt64(data[pos])
    pos += 1
    return v
  case 25:  // 2 bytes
    return UInt64(readUInt16(data, &pos))
  case 26:  // 4 bytes
    return UInt64(readUInt32(data, &pos))
  case 27:  // 8 bytes
    return readUInt64(data, &pos)
  default:
    throw JSONError.invalidCBOR("Reserved additional info \(info)")
  }
}

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
      data[pos + 3]) << 32 | UInt64(data[pos + 4]) << 24 | UInt64(data[pos + 5]) << 16 | UInt64(
      data[pos + 6]) << 8 | UInt64(data[pos + 7])
  pos += 8
  return value
}

private func halfToFloat(_ bits: UInt16) -> Double {
  let sign = Double((bits >> 15) == 0 ? 1 : -1)
  let exp = Int((bits >> 10) & 0x1F)
  let mant = UInt16(bits & 0x3FF)

  if exp == 0 {
    // Denormalized
    return sign * Double(mant) / 16384.0
  } else if exp == 31 {
    // NaN or Inf
    return mant == 0 ? (sign * Double.infinity) : Double.nan
  } else {
    // Normalized
    let bias = 15
    return sign * Double(mant | 0x400) * pow(2.0, Double(exp - bias - 10))
  }
}

// MARK: - CBOR encode

private func encodeCBOR(_ json: JSON, _ bytes: inout [UInt8]) {
  switch json.storage {
  case .null:
    bytes.append(0xF6)  // major 7, info 22 (null)

  case .boolean(let value):
    bytes.append(value ? 0xF5 : 0xF4)  // major 7, info 21/20

  case .number(let num):
    switch num {
    case .integer(let value):
      if value >= 0 {
        encodeCBORUnsigned(UInt64(value), &bytes, majorType: 0)
      } else {
        encodeCBORUnsigned(UInt64(-1 - value), &bytes, majorType: 1)
      }
    case .float(let value):
      let double = Double(value)
      let bits = double.bitPattern
      bytes.append(0xFB)
      appendUInt64(bits, &bytes)
    }

  case .string(let str):
    let utf8 = Data(str.utf8)
    encodeCBORUnsigned(UInt64(utf8.count), &bytes, majorType: 3)
    bytes.append(contentsOf: utf8)

  case .array(let arr):
    encodeCBORUnsigned(UInt64(arr.count), &bytes, majorType: 4)
    for element in arr {
      encodeCBOR(element, &bytes)
    }

  case .object(let dict):
    encodeCBORUnsigned(UInt64(dict.count), &bytes, majorType: 5)
    for (key, value) in dict {
      encodeCBORString(key, &bytes)
      encodeCBOR(value, &bytes)
    }
  }
}

private func encodeCBORUnsigned(_ value: UInt64, _ bytes: inout [UInt8], majorType: UInt8) {
  let mt = majorType << 5
  switch value {
  case 0...23:
    bytes.append(mt | UInt8(value))
  case 24...255:
    bytes.append(mt | 24)
    bytes.append(UInt8(value))
  case 256...65535:
    bytes.append(mt | 25)
    appendUInt16(UInt16(value), &bytes)
  case 65536...0xFFFF_FFFF:
    bytes.append(mt | 26)
    appendUInt32(UInt32(value), &bytes)
  case 0x1_0000_0000...:
    bytes.append(mt | 27)
    appendUInt64(value, &bytes)
  default:
    break
  }
}

private func encodeCBORString(_ str: String, _ bytes: inout [UInt8]) {
  let utf8 = Data(str.utf8)
  encodeCBORUnsigned(UInt64(utf8.count), &bytes, majorType: 3)
  bytes.append(contentsOf: utf8)
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
  /// Creates a CBOR-specific error wrapped in `invalidPatch`.
  /// - Parameter reason: A description of the error.
  /// - Returns: A `JSONError.invalidPatch` with the CBOR prefix.
  public static func invalidCBOR(_ reason: String = "") -> JSONError {
    return .invalidPatch("CBOR: \(reason)")
  }
}
