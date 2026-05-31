import Foundation
import Testing

@testable import OrderedJSON

@Suite("Codable Conformance Tests") struct JSONCodableConformanceTests {
  @Test("codable encode json object") func codableEncodeJSONObject() throws {
    let json = JSON.object([
      "name": .string("Alice"),
      "age": .number(.integer(30)),
    ])
    let data = try JSONEncoder().encode(json)
    let decoded = try JSONDecoder().decode(JSON.self, from: data)
    // Foundation's JSONDecoder sorts keys alphabetically, so order may differ
    #expect(decoded["name"] == .string("Alice"))
    #expect(decoded["age"] == .number(.integer(30)))
  }

  @Test("codable encode json array") func codableEncodeJSONArray() throws {
    let json = JSON.array([.string("a"), .number(.integer(1)), .boolean(true), .null])
    let data = try JSONEncoder().encode(json)
    let decoded = try JSONDecoder().decode(JSON.self, from: data)
    #expect(decoded.isArray)
    #expect(decoded.count == 4)
    #expect(decoded[0] == .string("a"))
    #expect(decoded[1] == .number(.integer(1)))
    #expect(decoded[2] == .boolean(true))
    #expect(decoded[3] == .null)
  }

  @Test("codable encode json scalar") func codableEncodeJSONScalar() throws {
    let json = JSON.string("hello")
    let data = try JSONEncoder().encode(json)
    let decoded = try JSONDecoder().decode(JSON.self, from: data)
    #expect(decoded == .string("hello"))
  }

  @Test("codable encode json null") func codableEncodeJSONNull() throws {
    let json = JSON.null
    let data = try JSONEncoder().encode(json)
    let decoded = try JSONDecoder().decode(JSON.self, from: data)
    #expect(decoded == .null)
  }

  @Test("codable encode json number") func codableEncodeJSONNumber() throws {
    let intJson = JSON.number(.integer(42))
    let intData = try JSONEncoder().encode(intJson)
    let intDecoded = try JSONDecoder().decode(JSON.self, from: intData)
    #expect(intDecoded.isInteger)

    let floatJson = JSON.number(.float(3.14))
    let floatData = try JSONEncoder().encode(floatJson)
    let floatDecoded = try JSONDecoder().decode(JSON.self, from: floatData)
    #expect(floatDecoded.isFloat)
  }
}
