import Testing

@testable import OrderedJSON

@Suite("Parser depth limit tests")
struct JSONParserDepthTests {
  @Test("depth at limit parses correctly")
  func depthAtLimitParsesCorrectly() throws {
    let opts = JSON.ParserOptions(maxDepth: 3)
    let result = try JSON.parse("{\"a\": {\"b\": {\"c\": 1}}}", options: opts)
    #expect(result["a"]?["b"]?["c"] == JSON.number(.integer(1)))
  }

  @Test("depth one over limit rejected")
  func depthOneOverLimitRejected() {
    let opts = JSON.ParserOptions(maxDepth: 3)
    // {"a": {"b": {"c": {"d": 1}}}} — 4 levels of nesting (depth exceeds 3)
    // Error at column where the 4th '{' is parsed
    #expect(throws: JSONParseError.depthExceeded(line: 1, column: 20, depth: 4, maxDepth: 3)) {
      try JSON.parse("{\"a\": {\"b\": {\"c\": {\"d\": 1}}}}", options: opts)
    }
  }

  @Test("depth two over limit rejected")
  func depthTwoOverLimitRejected() {
    let opts = JSON.ParserOptions(maxDepth: 3)
    #expect(throws: JSONParseError.depthExceeded(line: 1, column: 20, depth: 4, maxDepth: 3)) {
      try JSON.parse("{\"a\": {\"b\": {\"c\": {\"d\": {\"e\": 1}}}}}", options: opts)
    }
  }

  @Test("array depth at limit")
  func arrayDepthAtLimit() throws {
    let opts = JSON.ParserOptions(maxDepth: 3)
    let result = try JSON.parse("[[[1]]]", options: opts)
    #expect(result.isArray)
    #expect(result[0]?[0]?[0] == JSON.number(.integer(1)))
  }

  @Test("array depth over limit rejected")
  func arrayDepthOverLimitRejected() {
    let opts = JSON.ParserOptions(maxDepth: 3)
    // [[[[1]]]] — 4 levels of array nesting (depth exceeds 3)
    // Error at column 5: after 4th '[', depth=4 > maxDepth=3
    #expect(throws: JSONParseError.depthExceeded(line: 1, column: 5, depth: 4, maxDepth: 3)) {
      try JSON.parse("[[[[1]]]]", options: opts)
    }
  }

  @Test("depth limit with mixed arrays and objects")
  func depthLimitMixed() throws {
    let opts = JSON.ParserOptions(maxDepth: 4)
    let result = try JSON.parse("[{\"a\": [[1]]}]", options: opts)
    #expect(result[0]?["a"]?[0]?[0] == JSON.number(.integer(1)))
  }
}
