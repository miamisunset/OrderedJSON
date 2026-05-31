import Foundation
import Testing

@testable import OrderedJSON

@Suite("Parser memory/performance tests")
struct JSONParserPerformanceTests {
  @Test("maxDepth=1 rejects 2-level nesting ([[1]])")
  func maxDepth1Rejects2LevelNesting() {
    let opts = JSON.ParserOptions(maxDepth: 1)
    #expect(throws: JSONParseError.self) { try JSON.parse("[[1]]", options: opts) }
  }

  @Test("maxDepth=0 rejects any nesting")
  func maxDepth0RejectsAnyNesting() {
    let opts = JSON.ParserOptions(maxDepth: 0)
    #expect(throws: JSONParseError.self) { try JSON.parse("[]", options: opts) }
    #expect(throws: JSONParseError.self) { try JSON.parse("{}", options: opts) }
  }

  @Test("maxDepth=10 parses 10-deep nested arrays")
  func maxDepth10Handles10Deep() throws {
    var json = "1"
    for _ in 0..<10 { json = "[" + json + "]" }
    #expect(try JSON.parse(json).isArray)
  }

  @Test("maxDepth=10 rejects 11-deep nested arrays")
  func maxDepth10Rejects11Deep() {
    let opts = JSON.ParserOptions(maxDepth: 10)
    var json = "1"
    for _ in 0..<11 { json = "[" + json + "]" }
    #expect(throws: JSONParseError.self) { try JSON.parse(json, options: opts) }
  }

  @Test("parse 100K character string")
  func parseLargeString() throws {
    let longString = String(repeating: "a", count: 100_000)
    #expect(try JSON.parse("\"" + longString + "\"").stringValue == longString)
  }

  @Test("parse 1M character string")
  func parseVeryLargeString() throws {
    let longString = String(repeating: "b", count: 1_000_000)
    #expect(try JSON.parse("\"" + longString + "\"").stringValue == longString)
  }

  @Test("dump 100K character string")
  func dumpLargeString() throws {
    let longString = String(repeating: "c", count: 100_000)
    #expect(JSON.string(longString).dump() == "\"" + longString + "\"")
  }

  @Test("dump 1M character string compact")
  func dumpVeryLargeStringCompact() throws {
    let longString = String(repeating: "d", count: 1_000_000)
    #expect(JSON.string(longString).dump().count == 1_000_002)
  }

  @Test("parse string with many escaped characters")
  func parseStringWithManyEscapes() throws {
    let chunk = "\\\\\\\"\\n\\t\\r"
    let longEscaped = String(repeating: chunk, count: 10_000)
    #expect(try JSON.parse("\"" + longEscaped + "\"").isString)
  }

  @Test("parse string with many escaped quotes")
  func parseStringWithManyEscapedQuotes() throws {
    let inner = String(repeating: "\\\"", count: 50_000)
    #expect(try JSON.parse("\"" + inner + "\"").isString)
  }

  @Test("parse array with 10,000 elements")
  func parseLargeArray() throws {
    let elements = (0..<10_000).map { "\($0)" }.joined(separator: ",")
    let result = try JSON.parse("[" + elements + "]")
    #expect(result.isArray)
    #expect(result.count == 10_000)
  }

  @Test("parse array with 100,000 elements")
  func parseVeryLargeArray() throws {
    let elements = (0..<100_000).map { _ in "1" }.joined(separator: ",")
    let result = try JSON.parse("[" + elements + "]")
    #expect(result.isArray)
    #expect(result.count == 100_000)
  }

  @Test("dump array with 10,000 elements round-trips")
  func dumpLargeArrayRoundTrip() throws {
    let elements = (0..<10_000).map { JSON.number(.integer(Int64($0))) }
    let reparsed = try JSON.parse(JSON.array(elements).dump())
    #expect(reparsed.count == 10_000)
  }

  @Test("parse object with 10,000 keys")
  func parseLargeObject() throws {
    let keyValues = (0..<10_000).map { "\"k\($0)\":\($0)" }.joined(separator: ",")
    let result = try JSON.parse("{" + keyValues + "}")
    #expect(result.isObject)
    #expect(result.count == 10_000)
  }

  @Test("parse 50-deep array with 100 elements per level")
  func parseDeepWideArray() throws {
    var current = (0..<100).map { "\($0)" }.joined(separator: ",")
    current = "[" + current + "]"
    for _ in 0..<50 { current = "[" + current + "]" }
    #expect(try JSON.parse(current).isArray)
  }

  @Test("parse 50-deep object with 100 keys per level")
  func parseDeepWideObject() throws {
    var inner = (0..<100).map { "\"k\($0)\":\($0)" }.joined(separator: ",")
    inner = "{" + inner + "}"
    for _ in 0..<50 { inner = "{\"a\":" + inner + "}" }
    #expect(try JSON.parse(inner).isObject)
  }
}
