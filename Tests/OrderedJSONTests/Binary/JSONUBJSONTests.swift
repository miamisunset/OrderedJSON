import Foundation
import Testing

@testable import OrderedJSON

// MARK: - UBJSON Tests

@Suite("UBJSON tests")
struct JSONUBJSONTests {
  @Test("ubjson round trip null") func ubjsonRoundTripNull() throws {
    let json = JSON.null
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip bool") func ubjsonRoundTripBool() throws {
    let json = JSON.boolean(true)
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip bool false") func ubjsonRoundTripBoolFalse() throws {
    let json = JSON.boolean(false)
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip integer") func ubjsonRoundTripInteger() throws {
    let json = JSON.number(.integer(42))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip float") func ubjsonRoundTripFloat() throws {
    let json = JSON.number(.float(3.14))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip string") func ubjsonRoundTripString() throws {
    let json = JSON.string("hello")
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip array") func ubjsonRoundTripArray() throws {
    let json = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip object") func ubjsonRoundTripObject() throws {
    let json = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.string("x")])
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson negative integer") func ubjsonNegativeInteger() throws {
    let json = JSON.number(.integer(-42))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson large integer") func ubjsonLargeInteger() throws {
    let json = JSON.number(.integer(100_000))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson trailing bytes") func ubjsonTrailingBytes() throws {
    let json = JSON.number(.integer(1))
    let data = json.ubjson()
    var trailing = data
    trailing.append(0x00)
    #expect(throws: JSONError.self) {
      try JSON(ubjson: trailing)
    }
  }

  @Test("ubjson char marker") func ubjsonCharMarker() throws {
    // UBJSON char marker 'C' followed by a single character
    let bytes: [UInt8] = [0x43, 0x41]  // 'C', 'A'
    let data = Data(bytes)
    let decoded = try JSON(ubjson: data)
    #expect(decoded == JSON.string("A"))
  }

  @Test("ubjson empty data") func ubjsonEmptyData() throws {
    #expect(throws: JSONError.self) { try JSON(ubjson: Data()) }
  }

  @Test("ubjson unknown marker") func ubjsonUnknownMarker() throws {
    // UBJSON marker 'X' (not in spec)
    let bytes: [UInt8] = [0x58]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("ubjson string len unexpected end") func ubjsonStringLenUnexpectedEnd() throws {
    // UBJSON string marker with incomplete length marker
    let bytes: [UInt8] = [0x53]  // 'S' marker, no length
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("ubjson count unexpected end") func ubjsonCountUnexpectedEnd() throws {
    // UBJSON array marker with incomplete count
    let bytes: [UInt8] = [0x5B]  // '[' marker, no count
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("ubjson string marker not string") func ubjsonStringMarkerNotString() throws {
    // UBJSON object with non-string key marker
    let bytes: [UInt8] = [0x7B, 0x49, 0x01, 0x49, 0x02]  // object with int8 keys
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("ubjson large negative") func ubjsonLargeNegative() throws {
    let json = JSON.number(.integer(-1_000_000))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson string len int16 negative (throws)") func ubjsonStringLenInt16NegativeThrows()
    throws
  {
    // UBJSON string with Int16 length = -1 should throw
    let bytes: [UInt8] = [0x53, 0x49, 0xFF, 0xFF, 0x41]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("ubjson string len int32 negative (throws)") func ubjsonStringLenInt32NegativeThrows()
    throws
  {
    // UBJSON string with Int32 length = -1 should throw
    let bytes: [UInt8] = [0x53, 0x6C, 0xFF, 0xFF, 0xFF, 0xFF, 0x41]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("ubjson count int16 negative (throws)") func ubjsonCountInt16NegativeThrows() throws {
    // UBJSON array with Int16 count = -1 should throw
    let bytes: [UInt8] = [0x5B, 0x49, 0xFF, 0xFF]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("ubjson string len exceeds data (throws)") func ubjsonStringLenExceedsDataThrows() throws {
    // UBJSON string with length > available data should throw
    let bytes: [UInt8] = [0x53, 0x49, 0x64, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("ubjson truncated uint16 argument") func ubjsonTruncatedUInt16Argument() throws {
    // UBJSON int16 marker 'J' with only 1 byte (needs 2)
    let bytes: [UInt8] = [0x4A, 0x01]  // 'J', 1 byte (need 2)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("ubjson truncated uint32 argument") func ubjsonTruncatedUInt32Argument() throws {
    // UBJSON int32 marker with only 2 bytes (needs 4)
    let bytes: [UInt8] = [0x4C, 0x00, 0x00]  // 'L', 2 bytes (need 4)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("ubjson string len int16 truncated") func ubjsonStringLenInt16Truncated() throws {
    // UBJSON string with int16 length prefix, truncated before length
    // Marker 'S' + 'J' (int16 marker), then only 1 byte of length (needs 2)
    let bytes: [UInt8] = [0x53, 0x4A, 0x01]  // 'S', 'J', 1 byte (need 2)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("ubjson string len int32 truncated") func ubjsonStringLenInt32Truncated() throws {
    // UBJSON string with int32 length prefix, truncated before length
    // Marker 'S' + 'L' (int32 marker), then only 2 bytes of length (needs 4)
    let bytes: [UInt8] = [0x53, 0x4C, 0x00, 0x00]  // 'S', 'L', 2 bytes (need 4)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }
}

// MARK: - UBJSON/BJData String Length Marker Tests

@Suite("UBJSON/BJData string length edge tests")
struct JSONUBJSONBJDataStringLenTests {
  @Test("ubjson string len int32 max negative throws") func ubjsonStringLenInt32MaxNegativeThrows()
    throws
  {
    // UBJSON string with Int32 length marker, value = 0x80000000 (Int32.min as bits)
    // This produces a negative length after Int32(bitPattern:) → should throw
    // Marker 'S', then 'L' (int32), then 4 bytes: 0x80,0x00,0x00,0x00
    let bytes: [UInt8] = [0x53, 0x4C, 0x80, 0x00, 0x00, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("bjdata string len int32 max negative throws") func bjdataStringLenInt32MaxNegativeThrows()
    throws
  {
    // BJData string with Int32 length marker, value = 0x80000000 (Int32.min as bits)
    let bytes: [UInt8] = [0x53, 0x6C, 0x80, 0x00, 0x00, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata string len uint32 throws") func bjdataStringLenUInt32Throws() throws {
    // BJData string with UInt32 length marker — NOT supported by decoder
    // The decoder only supports Int8/UInt8/Int16/Int32 for string lengths
    let bytes: [UInt8] = [0x53, 0x6D, 0x03, 0x00, 0x00, 0x00, 0x41, 0x42, 0x43]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("ubjson string len int8 negative throws") func ubjsonStringLenInt8NegativeThrows() throws {
    // UBJSON string with Int8 length = -1
    let bytes: [UInt8] = [0x53, 0x49, 0xFF]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("bjdata string len int8 negative throws") func bjdataStringLenInt8NegativeThrows() throws {
    // BJData string with Int8 length = -1
    let bytes: [UInt8] = [0x53, 0x49, 0xFF]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata string len uint8 works") func bjdataStringLenUInt8Works() throws {
    // BJData string with UInt8 length marker — should work
    let bytes: [UInt8] = [0x53, 0x55, 0x03, 0x41, 0x42, 0x43]
    let data = Data(bytes)
    let decoded = try JSON(bjdata: data)
    #expect(decoded == JSON.string("ABC"))
  }
}
