import Foundation
import Testing

@testable import OrderedJSON

// MARK: - Round-trip Edge Value Tests

@Suite("Binary round-trip edge value tests")
struct JSONBinaryRoundTripEdgeTests {
  @Test("cbor round trip zero") func cborRoundTripZero() throws {
    let json = JSON.number(.integer(0))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor round trip int64 min") func cborRoundTripInt64Min() throws {
    let json = JSON.number(.integer(Int64.min))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor round trip int64 max") func cborRoundTripInt64Max() throws {
    let json = JSON.number(.integer(Int64.max))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor round trip negative zero float") func cborRoundTripNegativeZeroFloat() throws {
    let json = JSON.number(.float(-0.0))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -0.0)
    #expect(d.sign == .minus)
  }

  @Test("cbor round trip nan") func cborRoundTripNaN() throws {
    let json = JSON.number(.float(Double.nan))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d.isNaN)
  }

  @Test("cbor round trip infinity") func cborRoundTripInfinity() throws {
    let json = JSON.number(.float(Double.infinity))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double.infinity)
  }

  @Test("cbor round trip negative infinity") func cborRoundTripNegativeInfinity() throws {
    let json = JSON.number(.float(-Double.infinity))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -Double.infinity)
  }

  @Test("cbor round trip empty object") func cborRoundTripEmptyObject() throws {
    let json = JSON.object([:])
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor round trip empty array") func cborRoundTripEmptyArray() throws {
    let json = JSON.array([])
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor round trip nested structure") func cborRoundTripNested() throws {
    let inner = JSON.object(["x": JSON.number(.integer(42))])
    let json = JSON.array([inner, inner, JSON.null, JSON.boolean(true)])
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip zero") func msgPackRoundTripZero() throws {
    let json = JSON.number(.integer(0))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip int64 min") func msgPackRoundTripInt64Min() throws {
    let json = JSON.number(.integer(Int64.min))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip int64 max") func msgPackRoundTripInt64Max() throws {
    let json = JSON.number(.integer(Int64.max))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip negative zero float") func msgPackRoundTripNegativeZeroFloat() throws {
    let json = JSON.number(.float(-0.0))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -0.0)
  }

  @Test("msg pack round trip empty object") func msgPackRoundTripEmptyObject() throws {
    let json = JSON.object([:])
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip empty array") func msgPackRoundTripEmptyArray() throws {
    let json = JSON.array([])
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip nested") func msgPackRoundTripNested() throws {
    let inner = JSON.object(["x": JSON.number(.integer(42))])
    let json = JSON.array([inner, inner, JSON.null, JSON.boolean(true)])
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip zero") func ubjsonRoundTripZero() throws {
    let json = JSON.number(.integer(0))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip int64 min") func ubjsonRoundTripInt64Min() throws {
    let json = JSON.number(.integer(Int64.min))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip int64 max") func ubjsonRoundTripInt64Max() throws {
    let json = JSON.number(.integer(Int64.max))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip negative zero float") func ubjsonRoundTripNegativeZeroFloat() throws {
    let json = JSON.number(.float(-0.0))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -0.0)
  }

  @Test("ubjson round trip nan") func ubjsonRoundTripNaN() throws {
    let json = JSON.number(.float(Double.nan))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d.isNaN)
  }

  @Test("ubjson round trip infinity") func ubjsonRoundTripInfinity() throws {
    let json = JSON.number(.float(Double.infinity))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double.infinity)
  }

  @Test("ubjson round trip empty object") func ubjsonRoundTripEmptyObject() throws {
    let json = JSON.object([:])
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip empty array") func ubjsonRoundTripEmptyArray() throws {
    let json = JSON.array([])
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("ubjson round trip nested") func ubjsonRoundTripNested() throws {
    let inner = JSON.object(["x": JSON.number(.integer(42))])
    let json = JSON.array([inner, inner, JSON.null, JSON.boolean(true)])
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded == json)
  }

  @Test("bson round trip zero") func bsonRoundTripZero() throws {
    let json = JSON.number(.integer(0))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"] == json)
  }

  @Test("bson round trip int64 min") func bsonRoundTripInt64Min() throws {
    let json = JSON.number(.integer(Int64.min))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"] == json)
  }

  @Test("bson round trip int64 max") func bsonRoundTripInt64Max() throws {
    let json = JSON.number(.integer(Int64.max))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"] == json)
  }

  @Test("bson round trip negative zero float") func bsonRoundTripNegativeZeroFloat() throws {
    let json = JSON.number(.float(-0.0))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"]?.isFloat ?? false)
  }

  @Test("bson round trip nan") func bsonRoundTripNaN() throws {
    let json = JSON.number(.float(Double.nan))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"]?.isFloat ?? false)
  }

  @Test("bson round trip infinity") func bsonRoundTripInfinity() throws {
    let json = JSON.number(.float(Double.infinity))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"]?.isFloat ?? false)
  }

  @Test("bson round trip empty object") func bsonRoundTripEmptyObject() throws {
    let json = JSON.object([:])
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded == json)
  }

  @Test("bson round trip nested") func bsonRoundTripNested() throws {
    let inner = JSON.object(["x": JSON.number(.integer(42))])
    let json = JSON.object(["inner": inner, "flag": JSON.boolean(true)])
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip zero") func bjdataRoundTripZero() throws {
    let json = JSON.number(.integer(0))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip int64 min") func bjdataRoundTripInt64Min() throws {
    let json = JSON.number(.integer(Int64.min))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip int64 max") func bjdataRoundTripInt64Max() throws {
    let json = JSON.number(.integer(Int64.max))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip negative zero float") func bjdataRoundTripNegativeZeroFloat() throws {
    let json = JSON.number(.float(-0.0))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -0.0)
  }

  @Test("bjdata round trip nan") func bjdataRoundTripNaN() throws {
    let json = JSON.number(.float(Double.nan))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d.isNaN)
  }

  @Test("bjdata round trip infinity") func bjdataRoundTripInfinity() throws {
    let json = JSON.number(.float(Double.infinity))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double.infinity)
  }

  @Test("bjdata round trip empty object") func bjdataRoundTripEmptyObject() throws {
    let json = JSON.object([:])
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip empty array") func bjdataRoundTripEmptyArray() throws {
    let json = JSON.array([])
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }

  @Test("bjdata round trip nested") func bjdataRoundTripNested() throws {
    let inner = JSON.object(["x": JSON.number(.integer(42))])
    let json = JSON.array([inner, inner, JSON.null, JSON.boolean(true)])
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded == json)
  }
}

// MARK: - Missing Round-Trip Edge Tests

@Suite("Binary round-trip missing edge value tests")
struct JSONBinaryRoundTripMissingEdgeTests {
  @Test("msg pack round trip nan") func msgPackRoundTripNaN() throws {
    let json = JSON.number(.float(Double.nan))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d.isNaN)
  }

  @Test("msg pack round trip infinity") func msgPackRoundTripInfinity() throws {
    let json = JSON.number(.float(Double.infinity))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double.infinity)
  }

  @Test("msg pack round trip negative infinity") func msgPackRoundTripNegativeInfinity() throws {
    let json = JSON.number(.float(-Double.infinity))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -Double.infinity)
  }

  @Test("ubjson round trip negative infinity") func ubjsonRoundTripNegativeInfinity() throws {
    let json = JSON.number(.float(-Double.infinity))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -Double.infinity)
  }

  @Test("bson round trip negative infinity") func bsonRoundTripNegativeInfinity() throws {
    let json = JSON.number(.float(-Double.infinity))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded.isObject)
    guard case .object(let dict) = decoded.storage else {
      Issue.record("Expected object, got \(decoded)")
      return
    }
    let val = try #require(dict["value"])
    #expect(val.isFloat)
  }

  @Test("bjdata round trip negative infinity") func bjdataRoundTripNegativeInfinity() throws {
    let json = JSON.number(.float(-Double.infinity))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -Double.infinity)
  }

  @Test("msg pack round trip negative zero float") func msgPackRoundTripNegativeZeroFloat() throws {
    let json = JSON.number(.float(-0.0))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -0.0)
    // MsgPack float64 preserves sign bit
    #expect(d.sign == .minus)
  }

  @Test("ubjson round trip negative zero float sign") func ubjsonRoundTripNegativeZeroFloatSign()
    throws
  {
    let json = JSON.number(.float(-0.0))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -0.0)
    #expect(d.sign == .minus)
  }

  @Test("bjdata round trip negative zero float sign") func bjdataRoundTripNegativeZeroFloatSign()
    throws
  {
    let json = JSON.number(.float(-0.0))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -0.0)
    #expect(d.sign == .minus)
  }

  @Test("cbor round trip large uint64 as float") func cborRoundTripLargeUInt64AsFloat() throws {
    // CBOR: encode a float that represents a value > Int64.max
    let json = JSON.number(.float(Double(UInt64(Int64.max) + 1)))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double(UInt64(Int64.max) + 1))
  }

  @Test("msg pack round trip large uint64 as float") func msgPackRoundTripLargeUInt64AsFloat()
    throws
  {
    let json = JSON.number(.float(Double(UInt64(Int64.max) + 1)))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double(UInt64(Int64.max) + 1))
  }

  @Test("ubjson round trip large uint64 as float") func ubjsonRoundTripLargeUInt64AsFloat() throws {
    let json = JSON.number(.float(Double(UInt64(Int64.max) + 1)))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double(UInt64(Int64.max) + 1))
  }

  @Test("bjdata round trip large uint64 as float") func bjdataRoundTripLargeUInt64AsFloat() throws {
    let json = JSON.number(.float(Double(UInt64(Int64.max) + 1)))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double(UInt64(Int64.max) + 1))
  }

  @Test("cbor round trip negative zero float encode") func cborRoundTripNegativeZeroFloatEncode()
    throws
  {
    // Verify CBOR encode of -0.0 uses float64, preserving sign
    let json = JSON.number(.float(-0.0))
    let data = json.cbor()
    // CBOR float64 has sign bit — should be preserved
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d.sign == .minus)
  }
}
