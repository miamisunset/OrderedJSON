import Foundation
import Testing

@testable import OrderedJSON

@Suite("Invalid Input Tests") struct JSONInvalidInputTests {
  @Test("invalid url string throws") func invalidURLStringThrows() throws {
    struct Container: Decodable {
      let url: URL
    }
    let decoder = OrderedJSONDecoder()
    // Empty string should throw dataCorrupted, not crash
    let json = JSON.object(["url": .string("")])
    #expect {
      try decoder.decode(Container.self, from: json)
    } throws: { error in
      guard let decodingError = error as? DecodingError else { return false }
      switch decodingError {
      case .dataCorrupted(let ctx):
        return ctx.debugDescription.contains("Invalid URL")
      default: return false
      }
    }
  }

  @Test("invalid uuid string throws") func invalidUUIDStringThrows() throws {
    struct Container: Decodable {
      let id: UUID
    }
    let decoder = OrderedJSONDecoder()
    // Invalid UUID format should throw dataCorrupted, not crash
    let json = JSON.object(["id": .string("not-a-uuid")])
    #expect {
      try decoder.decode(Container.self, from: json)
    } throws: { error in
      guard let decodingError = error as? DecodingError else { return false }
      switch decodingError {
      case .dataCorrupted(let ctx):
        return ctx.debugDescription.contains("Invalid UUID")
      default: return false
      }
    }
  }

  @Test("invalid decimal string throws") func invalidDecimalStringThrows() throws {
    struct Container: Decodable {
      let amount: Decimal
    }
    let decoder = OrderedJSONDecoder()
    // Non-numeric string should throw dataCorrupted, not return Decimal.nan
    let json = JSON.object(["amount": .string("not-a-number")])
    #expect {
      try decoder.decode(Container.self, from: json)
    } throws: { error in
      guard let decodingError = error as? DecodingError else { return false }
      switch decodingError {
      case .dataCorrupted(let ctx):
        return ctx.debugDescription.contains("Invalid Decimal")
      default: return false
      }
    }
  }

  @Test("invalid decimal as number throws") func invalidDecimalAsNumberThrows() throws {
    struct Container: Decodable {
      let amount: Decimal
    }
    var decoder = OrderedJSONDecoder()
    decoder.decimalDecodingStrategy = .asNumber
    // Non-number value should throw typeMismatch, not return Decimal.nan
    let json = JSON.object(["amount": .string("not-a-number")])
    #expect {
      try decoder.decode(Container.self, from: json)
    } throws: { error in
      guard let decodingError = error as? DecodingError else { return false }
      switch decodingError {
      case .typeMismatch:
        return true
      default: return false
      }
    }
  }
}
