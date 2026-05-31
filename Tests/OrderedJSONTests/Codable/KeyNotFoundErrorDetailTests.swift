import Foundation
import Testing

@testable import OrderedJSON

@Suite("Key Not Found Error Details") struct KeyNotFoundErrorDetailTests {
  @Test("missing key in decoder has correct key name") func missingKeyCorrectKeyName() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    let json = JSON.object(["name": .string("Alice")])
    let decoder = OrderedJSONDecoder()
    #expect {
      try decoder.decode(Person.self, from: json)
    } throws: { error in
      guard let decodingError = error as? DecodingError else { return false }
      switch decodingError {
      case .keyNotFound(let key, _):
        return key.stringValue == "age"
      default: return false
      }
    }
  }

  @Test("type mismatch on object expected array") func typeMismatchObjectExpectedArray() throws {
    struct Container: Decodable {
      let items: [Int]
    }
    let json = JSON.object(["items": .object([:])])
    let decoder = OrderedJSONDecoder()
    #expect(throws: DecodingError.self) {
      try decoder.decode(Container.self, from: json)
    }
  }
}
