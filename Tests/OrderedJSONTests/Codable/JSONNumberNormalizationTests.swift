import Foundation
import Testing

@testable import OrderedJSON

@Suite("Number Normalization Tests") struct JSONNumberNormalizationTests {
  @Test("number normalization clean double") func numberNormalizationCleanDouble() throws {
    let data = Data("42.0".utf8)
    let decoded = try JSONDecoder().decode(JSON.self, from: data)
    #expect(decoded.isInteger)
    #expect(decoded == .number(.integer(42)))
  }

  @Test("number normalization fractional double") func numberNormalizationFractionalDouble() throws
  {
    let data = Data("3.14".utf8)
    let decoded = try JSONDecoder().decode(JSON.self, from: data)
    #expect(decoded.isFloat)
  }

  @Test("number normalization large integer") func numberNormalizationLargeInteger() throws {
    let data = Data("1.0e20".utf8)
    let decoded = try JSONDecoder().decode(JSON.self, from: data)
    #expect(decoded.isFloat)
  }
}
