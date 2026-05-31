import Foundation
import Testing

@testable import OrderedJSON

@Suite("JSONWithExtras Validation Tests") struct JSONWithExtrasValidationTests {
  @Test("json with extras non object extras throws on encode")
  func jsonWithExtrasNonObjectExtrasThrowsOnEncode() throws {
    struct Person: Codable {
      let name: String
    }
    let wrapped = JSONWithUnknownKeys(
      value: Person(name: "Alice"),
      unknownKeys: .null
    )
    let encoder = JSONEncoder()
    #expect {
      try encoder.encode(wrapped)
    } throws: { error in
      guard let encodingError = error as? EncodingError else { return false }
      switch encodingError {
      case .invalidValue(_, let ctx):
        return ctx.debugDescription.contains("Unknown keys must be a JSON object")
      default: return false
      }
    }
  }
}
