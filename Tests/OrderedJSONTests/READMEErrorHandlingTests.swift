import Testing

@testable import OrderedJSON

@Test func readmeErrorHandling() throws {
  do {
    let _ = try JSON.parse("{\"a\": }")
  } catch let error as JSONParseError {
    let desc = String(describing: error)
    #expect(desc.contains("line") || desc.contains("Expected"))
  }
}
