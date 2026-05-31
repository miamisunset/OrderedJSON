import Foundation
import Testing

@testable import OrderedJSON

@Test func readmeBinaryFormats() throws {
  let json = JSON.object([
    "name": JSON.string("Bob"),
    "age": JSON.number(.integer(25)),
  ])

  // CBOR
  let cbor = json.cbor()
  let back = try JSON(cbor: cbor)
  #expect(back == json)

  // MessagePack
  let msg = json.msgPack()
  let back2 = try JSON(msgPack: msg)
  #expect(back2 == json)

  // UBJSON
  let ubj = json.ubjson()
  let back3 = try JSON(ubjson: ubj)
  #expect(back3 == json)

  // BSON
  let bson = json.bson()
  let back4 = try JSON(bson: bson)
  #expect(back4 == json)

  // BJData
  let bjd = json.bjdata()
  let back5 = try JSON(bjdata: bjd)
  #expect(back5 == json)
}
