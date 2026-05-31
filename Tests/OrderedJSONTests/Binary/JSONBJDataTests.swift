import Foundation
import Testing

@testable import OrderedJSON

// MARK: - BJData Tests

@Suite("BJData tests")
struct JSONBJDataTests {
  @Test("bjdata round trip null") func bjdataRoundTripNull() throws {
    let json = JSON.null
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip bool") func bjdataRoundTripBool() throws {
    let json = JSON.boolean(true)
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip bool false") func bjdataRoundTripBoolFalse() throws {
    let json = JSON.boolean(false)
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip integer") func bjdataRoundTripInteger() throws {
    let json = JSON.number(.integer(42))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip float") func bjdataRoundTripFloat() throws {
    let json = JSON.number(.float(3.14))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip string") func bjdataRoundTripString() throws {
    let json = JSON.string("hello")
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip array") func bjdataRoundTripArray() throws {
    let json = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip object") func bjdataRoundTripObject() throws {
    let json = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.string("x")])
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata negative integer") func bjdataNegativeInteger() throws {
    let json = JSON.number(.integer(-42))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata large integer") func bjdataLargeInteger() throws {
    let json = JSON.number(.integer(100_000))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata trailing bytes") func bjdataTrailingBytes() throws {
    let json = JSON.number(.integer(1))
    let data = json.bjdata()
    var trailing = data
    trailing.append(0x00)
    #expect(throws: JSONError.self) {
      try JSON(bjdata: trailing)
    }
  }

  @Test("bjdata char marker") func bjdataCharMarker() throws {
    // BJData char marker 'C' followed by a single character
    let bytes: [UInt8] = [0x43, 0x41]  // 'C', 'A'
    let data = Data(bytes)
    let decoded = try JSON(bjdata: data)
    #expect(decoded == JSON.string("A"))
  }

  @Test("bjdata empty data") func bjdataEmptyData() throws {
    #expect(throws: JSONError.self) { try JSON(bjdata: Data()) }
  }

  @Test("bjdata unknown marker") func bjdataUnknownMarker() throws {
    // BJData marker 'X' (not in spec)
    let bytes: [UInt8] = [0x58]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata string len unexpected end") func bjdataStringLenUnexpectedEnd() throws {
    // BJData string marker with incomplete length marker
    let bytes: [UInt8] = [0x53]  // 'S' marker, no length
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata string marker not string") func bjdataStringMarkerNotString() throws {
    // BJData object with non-string key marker
    let bytes: [UInt8] = [0x7B, 0x49, 0x01, 0x49, 0x02]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata large negative") func bjdataLargeNegative() throws {
    let json = JSON.number(.integer(-1_000_000))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata string len int16 negative (throws)") func bjdataStringLenInt16NegativeThrows()
    throws
  {
    // BJData string with Int16 length = -1 should throw
    let bytes: [UInt8] = [0x53, 0x49, 0xFF, 0xFF, 0x41]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata string len int32 negative (throws)") func bjdataStringLenInt32NegativeThrows()
    throws
  {
    // BJData string with Int32 length = -1 should throw
    let bytes: [UInt8] = [0x53, 0x6C, 0xFF, 0xFF, 0xFF, 0xFF, 0x41]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata string len exceeds data (throws)") func bjdataStringLenExceedsDataThrows() throws {
    // BJData string with length > available data should throw
    let bytes: [UInt8] = [0x53, 0x49, 0x64, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata truncated uint16 argument") func bjdataTruncatedUInt16Argument() throws {
    // BJData int16 marker 'J' with only 1 byte (needs 2)
    let bytes: [UInt8] = [0x4A, 0x01]  // 'J', 1 byte (need 2)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata truncated uint32 argument") func bjdataTruncatedUInt32Argument() throws {
    // BJData int32 marker with only 2 bytes (needs 4)
    let bytes: [UInt8] = [0x4C, 0x00, 0x00]  // 'L', 2 bytes (need 4)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata string len int16 truncated") func bjdataStringLenInt16Truncated() throws {
    // BJData string with int16 length prefix, truncated
    let bytes: [UInt8] = [0x53, 0x4A, 0x01]  // 'S', 'J', 1 byte (need 2)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata string len int32 truncated") func bjdataStringLenInt32Truncated() throws {
    // BJData string with int32 length prefix, truncated
    let bytes: [UInt8] = [0x53, 0x4C, 0x00, 0x00]  // 'S', 'L', 2 bytes (need 4)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata array missing end marker (throws)") func bjdataArrayMissingEndMarker() throws {
    // BJData array with no ']' end marker
    let bytes: [UInt8] = [0x5B, 0x49, 0x01]  // '[', int8 1 — no ']'
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata object missing end marker (throws)") func bjdataObjectMissingEndMarker() throws {
    // BJData object with no '}' end marker
    let bytes: [UInt8] = [0x7B, 0x53, 0x49, 0x01, 0x61]  // '{', string "a" — no '}'
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata empty array with end markers") func bjdataEmptyArrayWithEndMarkers() throws {
    // BJData empty array with end markers: '[' + ']'
    let bytes: [UInt8] = [0x5B, 0x5D]  // '[', ']'
    let data = Data(bytes)
    let decoded = try JSON(bjdata: data)
    #expect(decoded.isArray)
    #expect(decoded.count == 0)
  }

  @Test("bjdata empty object with end markers") func bjdataEmptyObjectWithEndMarkers() throws {
    // BJData empty object with end markers: '{' + '}'
    let bytes: [UInt8] = [0x7B, 0x7D]  // '{', '}'
    let data = Data(bytes)
    let decoded = try JSON(bjdata: data)
    #expect(decoded.isObject)
    #expect(decoded.count == 0)
  }

  @Test("bjdata mismatched end marker (throws)") func bjdataMismatchedEndMarker() throws {
    // BJData array with '}' end marker (object end inside array) should throw
    let bytes: [UInt8] = [0x5B, 0x49, 0x01, 0x7D]  // '[', int8 1, '}' — mismatched
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }
}

// MARK: - BJData End Marker Edge Tests

@Suite("BJData end marker edge tests")
struct JSONBJDataEndMarkerEdgeTests {
  @Test("bjdata empty array then more data") func bjdataEmptyArrayThenData() throws {
    // BJData: '[', ']' then trailing data should throw
    let bytes: [UInt8] = [0x5B, 0x5D, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata array with end marker at wrong position") func bjdataArrayEndMarkerWrongPos()
    throws
  {
    // BJData: '[' with no end marker — runs out of data
    let bytes: [UInt8] = [0x5B]  // just '[', no ']'
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata object with end marker at wrong position") func bjdataObjectEndMarkerWrongPos()
    throws
  {
    // BJData: '{' with no end marker — runs out of data
    let bytes: [UInt8] = [0x7B]  // just '{', no '}'
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata mismatched end marker in array") func bjdataMismatchedEndMarkerInArray() throws {
    // BJData array with '}' end marker inside (mismatched)
    // The '}' is not ']' so it tries to decode it as a value → unknown marker error
    let bytes: [UInt8] = [0x5B, 0x7D]  // '[', '}' — '}' is not ']'
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata mismatched end marker in object") func bjdataMismatchedEndMarkerInObject() throws {
    // BJData object with ']' end marker inside (mismatched)
    let bytes: [UInt8] = [0x7B, 0x5D]  // '{', ']' — ']' is not '}'
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }
}
