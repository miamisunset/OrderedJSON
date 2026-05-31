import Foundation
import Testing

@testable import OrderedJSON

@Test func readmeParsingFromData() throws {
  let data = "{\"key\": \"value\"}".data(using: .utf8)!
  let parsed = try JSON.parse(data)
  #expect(parsed["key"] == JSON.string("value"))

  // With options
  let opts = JSON.ParserOptions(allowTrailingCommas: true)
  let parsed2 = try JSON.parse(data, options: opts)
  #expect(parsed2["key"] == JSON.string("value"))
}
