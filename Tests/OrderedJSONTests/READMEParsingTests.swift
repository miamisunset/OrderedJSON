import Testing

@testable import OrderedJSON

@Test func readmeParsing() throws {
  let jsonString = """
    {"c": 3, "a": 1, "b": 2}
    """
  let parsed = try JSON.parse(jsonString)
  #expect(parsed.isObject)
  #expect(parsed.count == 3)
}

@Test func readmeDuplicateKeys() throws {
  let dupes = try JSON.parse(
    """
    {"x": 1, "x": 2, "x": 3}
    """)
  #expect(dupes["x"] == JSON.number(.integer(3)))
}

@Test func readmeParserOptions() throws {
  // Default options
  let _ = JSON.ParserOptions.default

  // Custom options
  var opts = JSON.ParserOptions(allowTrailingCommas: true)
  opts.maxDepth = 512

  // Trailing commas
  let trailing = try JSON.parse("[1, 2, 3,]", options: opts)
  #expect(trailing.isArray)
  #expect(trailing.count == 3)

  // Safety: limit nesting
  let safe = JSON.ParserOptions(maxDepth: 64)
  let untrustedInput = "{\"a\": 1}"
  let parsed = try JSON.parse(untrustedInput, options: safe)
  #expect(parsed.isObject)
}
