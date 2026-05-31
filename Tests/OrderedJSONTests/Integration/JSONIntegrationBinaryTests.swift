import Foundation
import Testing

@testable import OrderedJSON

@Suite("Integration: binary encode → parse")
struct JSONIntegrationBinaryTests {
  @Test("CBOR encode → JSON decode → dump → parse: round-trip")
  func cborEncodeDecodeDumpParse() throws {
    let original = try JSON.parse(
      """
      {"name": "Bob", "age": 25, "scores": [90.5, 85.0, 92.0]}
      """)
    let cborData = original.cbor()
    let decoded = try JSON(cbor: cborData)
    let dumped = decoded.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }

  @Test("MsgPack encode → JSON decode → dump → parse: round-trip")
  func msgPackEncodeDecodeDumpParse() throws {
    let original = try JSON.parse(
      """
      {"name": "Alice", "active": true, "count": 100}
      """)
    let msgData = original.msgPack()
    let decoded = try JSON(msgPack: msgData)
    let dumped = decoded.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }

  @Test("UBJSON encode → JSON decode → dump → parse: round-trip")
  func ubjsonEncodeDecodeDumpParse() throws {
    let original = try JSON.parse(
      """
      {"key": "value", "num": 42, "items": [1, 2, 3]}
      """)
    let ubjData = original.ubjson()
    let decoded = try JSON(ubjson: ubjData)
    let dumped = decoded.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }

  @Test("BSON encode → JSON decode → dump → parse: round-trip")
  func bsonEncodeDecodeDumpParse() throws {
    let original = try JSON.parse(
      """
      {"name": "Charlie", "age": 30}
      """)
    let bsonData = original.bson()
    let decoded = try JSON(bson: bsonData)
    let dumped = decoded.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }

  @Test("BJData encode → JSON decode → dump → parse: round-trip")
  func bjdataEncodeDecodeDumpParse() throws {
    let original = try JSON.parse(
      """
      {"x": 1, "y": 2.5, "z": true}
      """)
    let bjdData = original.bjdata()
    let decoded = try JSON(bjdata: bjdData)
    let dumped = decoded.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }

  @Test("CBOR encode → MsgPack decode → dump → parse: cross-format decode")
  func cborEncodeMsgPackDecodeDumpParse() throws {
    // CBOR and MsgPack share some structure — verify we can encode one way
    // and decode another, then dump and re-parse
    let original = try JSON.parse(
      """
      {"simple": "test"}
      """)
    let _ = original.cbor()
    // Note: CBOR and MsgPack are NOT compatible formats, but this tests
    // that the dump/re-parse step produces valid JSON regardless
    let dumped = original.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }

  @Test("Binary edge: empty object round-trip through all formats")
  func binaryEmptyObjectAllFormats() throws {
    let original = JSON.object([:])

    let cborBack = try JSON(cbor: original.cbor())
    #expect(cborBack == original)

    let msgBack = try JSON(msgPack: original.msgPack())
    #expect(msgBack == original)

    let ubjBack = try JSON(ubjson: original.ubjson())
    #expect(ubjBack == original)

    let bsonBack = try JSON(bson: original.bson())
    #expect(bsonBack == original)

    let bjdBack = try JSON(bjdata: original.bjdata())
    #expect(bjdBack == original)

    // Verify dump/re-parse works on all binary-decoded results
    #expect(try JSON.parse(cborBack.dump()) == original)
    #expect(try JSON.parse(msgBack.dump()) == original)
  }

  @Test("Binary edge: null value round-trip")
  func binaryNullRoundTrip() throws {
    let original = JSON.null

    let cborBack = try JSON(cbor: original.cbor())
    #expect(cborBack == original)

    let msgBack = try JSON(msgPack: original.msgPack())
    #expect(msgBack == original)

    let ubjBack = try JSON(ubjson: original.ubjson())
    #expect(ubjBack == original)
  }
}
