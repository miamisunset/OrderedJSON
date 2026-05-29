import Foundation
import Testing

@testable import OrderedJSON

struct SAXCollector: JSONSAXEventHandler {
  final class State {
    var events: [(String, String)] = []
    var stopAfter: Int?
    var eventCount = 0
  }
  private let _state: State

  var events: [(String, String)] { _state.events }

  init() { _state = State() }

  func null() -> Bool {
    _state.record("null")
    return _state.shouldContinue()
  }

  func boolean(_ value: Bool) -> Bool {
    _state.record("boolean", "\(value)")
    return _state.shouldContinue()
  }

  func integer(_ value: Int64) -> Bool {
    _state.record("integer", "\(value)")
    return _state.shouldContinue()
  }

  func float(_: Double, string: String) -> Bool {
    _state.record("float", string)
    return _state.shouldContinue()
  }

  func string(_ value: String) -> Bool {
    _state.record("string", value)
    return _state.shouldContinue()
  }

  func startObject() -> Bool {
    _state.record("startObject")
    return _state.shouldContinue()
  }

  func key(_ value: String) -> Bool {
    _state.record("key", value)
    return _state.shouldContinue()
  }

  func endObject() -> Bool {
    _state.record("endObject")
    return _state.shouldContinue()
  }

  func startArray() -> Bool {
    _state.record("startArray")
    return _state.shouldContinue()
  }

  func endArray() -> Bool {
    _state.record("endArray")
    return _state.shouldContinue()
  }

  func parseError(_ error: JSONParseError, data _: Data) -> Bool {
    _state.record("error", "\(error)")
    return false
  }
}

extension SAXCollector.State {
  fileprivate func record(_ e: String, _ v: String = "") {
    events.append((e, v))
    eventCount += 1
  }

  fileprivate func shouldContinue() -> Bool {
    if let stop = stopAfter {
      return eventCount < stop
    }
    return true
  }
}

@Suite("SAX parse tests")
struct JSONSAXParseTests {
  @Test("sax parse null") func saxParseNull() {
    let collector = SAXCollector()
    let result = JSON.parse("null", handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 1)
    #expect(collector.events[0].0 == "null")
  }

  @Test("sax parse boolean true") func saxParseBooleanTrue() {
    let collector = SAXCollector()
    let result = JSON.parse("true", handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 1)
    #expect(collector.events[0] == ("boolean", "true"))
  }

  @Test("sax parse boolean false") func saxParseBooleanFalse() {
    let collector = SAXCollector()
    let result = JSON.parse("false", handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 1)
    #expect(collector.events[0] == ("boolean", "false"))
  }

  @Test("sax parse integer") func saxParseInteger() {
    let collector = SAXCollector()
    let result = JSON.parse("42", handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 1)
    #expect(collector.events[0] == ("integer", "42"))
  }

  @Test("sax parse negative integer") func saxParseNegativeInteger() {
    let collector = SAXCollector()
    let result = JSON.parse("-42", handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 1)
    #expect(collector.events[0] == ("integer", "-42"))
  }

  @Test("sax parse float") func saxParseFloat() {
    let collector = SAXCollector()
    let result = JSON.parse("3.14", handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 1)
    #expect(collector.events[0].0 == "float")
    #expect(collector.events[0].1 == "3.14")
  }

  @Test("sax parse string") func saxParseString() {
    let collector = SAXCollector()
    let result = JSON.parse("\"hello\"", handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 1)
    #expect(collector.events[0] == ("string", "hello"))
  }

  @Test("sax parse empty object") func saxParseEmptyObject() {
    let collector = SAXCollector()
    let result = JSON.parse("{}", handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 2)
    #expect(collector.events[0].0 == "startObject")
    #expect(collector.events[1].0 == "endObject")
  }

  @Test("sax parse empty array") func saxParseEmptyArray() {
    let collector = SAXCollector()
    let result = JSON.parse("[]", handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 2)
    #expect(collector.events[0].0 == "startArray")
    #expect(collector.events[1].0 == "endArray")
  }

  @Test("sax parse simple object") func saxParseSimpleObject() {
    let collector = SAXCollector()
    let result = JSON.parse(#"{"key": "value"}"#, handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 4)
    #expect(collector.events[0].0 == "startObject")
    #expect(collector.events[1] == ("key", "key"))
    #expect(collector.events[2] == ("string", "value"))
    #expect(collector.events[3].0 == "endObject")
  }

  @Test("sax parse simple array") func saxParseSimpleArray() {
    let collector = SAXCollector()
    let result = JSON.parse("[1, 2, 3]", handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 5)
    #expect(collector.events[0].0 == "startArray")
    #expect(collector.events[1] == ("integer", "1"))
    #expect(collector.events[2] == ("integer", "2"))
    #expect(collector.events[3] == ("integer", "3"))
    #expect(collector.events[4].0 == "endArray")
  }

  @Test("sax parse nested object") func saxParseNestedObject() {
    let collector = SAXCollector()
    let result = JSON.parse(#"{"a": {"b": 1}}"#, handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 7)
    #expect(collector.events[0].0 == "startObject")
    #expect(collector.events[1] == ("key", "a"))
    #expect(collector.events[2].0 == "startObject")
    #expect(collector.events[3] == ("key", "b"))
    #expect(collector.events[4] == ("integer", "1"))
    #expect(collector.events[5].0 == "endObject")
    #expect(collector.events[6].0 == "endObject")
  }

  @Test("sax parse nested array") func saxParseNestedArray() {
    let collector = SAXCollector()
    let result = JSON.parse("[[1, 2], [3]]", handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 9)
    #expect(collector.events[0].0 == "startArray")
    #expect(collector.events[1].0 == "startArray")
    #expect(collector.events[2] == ("integer", "1"))
    #expect(collector.events[3] == ("integer", "2"))
    #expect(collector.events[4].0 == "endArray")
    #expect(collector.events[5].0 == "startArray")
    #expect(collector.events[6] == ("integer", "3"))
    #expect(collector.events[7].0 == "endArray")
    #expect(collector.events[8].0 == "endArray")
  }

  @Test("sax parse mixed") func saxParseMixed() {
    let collector = SAXCollector()
    let result = JSON.parse(#"{"arr": [null, true], "val": "s"}"#, handler: collector)
    #expect(result == true)
    #expect(collector.events.count == 9)
    #expect(collector.events[0].0 == "startObject")
    #expect(collector.events[1] == ("key", "arr"))
    #expect(collector.events[2].0 == "startArray")
    #expect(collector.events[3].0 == "null")
    #expect(collector.events[4] == ("boolean", "true"))
    #expect(collector.events[5].0 == "endArray")
    #expect(collector.events[6] == ("key", "val"))
    #expect(collector.events[7] == ("string", "s"))
    #expect(collector.events[8].0 == "endObject")
  }

  @Test("sax parse error invalid token") func saxParseErrorInvalidToken() {
    let collector = SAXCollector()
    let result = JSON.parse("invalid", handler: collector)
    #expect(result == false)
    #expect(collector.events[0].0 == "error")
  }

  @Test("sax parse error unexpected end") func saxParseErrorUnexpectedEnd() {
    let collector = SAXCollector()
    let result = JSON.parse("{", handler: collector)
    #expect(result == false)
    #expect(collector.events[0].0 == "startObject")
    #expect(collector.events[1].0 == "key")
    #expect(collector.events[2].0 == "error")
  }

  @Test("sax parse error trailing garbage") func saxParseErrorTrailingGarbage() {
    let collector = SAXCollector()
    let result = JSON.parse("1 2", handler: collector)
    #expect(result == false)
    #expect(collector.events[0].0 == "integer")
    #expect(collector.events[1].0 == "error")
  }
}

@Suite("SAX accept tests")
struct JSONSAXAcceptTests {
  @Test("sax accept valid") func saxAcceptValid() {
    #expect(JSON.accept("null") == true)
    #expect(JSON.accept("true") == true)
    #expect(JSON.accept("42") == true)
    #expect(JSON.accept("\"hi\"") == true)
    #expect(JSON.accept("{}") == true)
    #expect(JSON.accept("[]") == true)
    #expect(JSON.accept(#"{"k":"v"}"#) == true)
    #expect(JSON.accept("[1,2]") == true)
  }

  @Test("sax accept invalid") func saxAcceptInvalid() {
    #expect(JSON.accept("") == false)
    #expect(JSON.accept("invalid") == false)
    #expect(JSON.accept("{") == false)
    #expect(JSON.accept("[") == false)
    #expect(JSON.accept("}") == false)
    #expect(JSON.accept("]") == false)
    #expect(JSON.accept(#"{"k":}"#) == false)
    #expect(JSON.accept("[1,]") == false)
  }
}

@Suite("SAX edge case tests")
struct JSONSAXEdgeCaseTests {
  @Test("sax parse invalid escape") func saxParseInvalidEscape() {
    let collector = SAXCollector()
    let result = JSON.parse("\"\\x\"", handler: collector)
    #expect(result == false)
  }

  @Test("sax parse invalid unicode") func saxParseInvalidUnicode() {
    let collector = SAXCollector()
    let result = JSON.parse("\"\\u\"", handler: collector)
    #expect(result == true)
    #expect(collector.events[0] == ("string", ""))
  }

  @Test("sax parse invalid unicode hex") func saxParseInvalidUnicodeHex() {
    let collector = SAXCollector()
    let result = JSON.parse("\"\\uQQQQ\"", handler: collector)
    #expect(result == true)
    #expect(collector.events[0].0 == "string")
    #expect(collector.events[0].1 == "")
  }

  @Test("sax parse incomplete float") func saxParseIncompleteFloat() {
    let collector = SAXCollector()
    let result = JSON.parse("1.0e+", handler: collector)
    #expect(result == false)
  }

  @Test("sax parse incomplete number") func saxParseIncompleteNumber() {
    let collector = SAXCollector()
    let result = JSON.parse("-", handler: collector)
    #expect(result == false)
  }

  @Test("sax parse backslash at end") func saxParseBackslashAtEnd() {
    let collector = SAXCollector()
    let result = JSON.parse("\"\\", handler: collector)
    #expect(result == true)
    #expect(collector.events[0] == ("string", ""))
  }

  @Test("sax parse number incomplete float") func saxParseNumberIncompleteFloat() {
    let collector = SAXCollector()
    let result = JSON.parse("0.0e", handler: collector)
    #expect(result == false)
  }

  @Test("sax accept incomplete object") func saxAcceptIncompleteObject() {
    #expect(JSON.accept("{\"a\":") == false)
  }

  @Test("sax accept incomplete array") func saxAcceptIncompleteArray() {
    #expect(JSON.accept("[1,") == false)
  }

  @Test("sax accept missing colon") func saxAcceptMissingColon() {
    #expect(JSON.accept("{\"a\" 1}") == false)
  }

  @Test("sax parse unicode escape followed by char") func saxParseUnicodeEscapeFollowedByChar() {
    let collector = SAXCollector()
    let jsonString = "{\"key\\u0041X\": 1}"
    let ok = JSON.parse(jsonString, handler: collector)
    #expect(ok)
    let expectedKey = "keyAX"
    #expect(collector.events.count >= 2)
    if collector.events.count >= 2 {
      let (event, value) = collector.events[1]
      #expect(event == "key")
      #expect(value == expectedKey)
    }
  }
}

@Suite("SAX early termination tests")
struct JSONSAXEarlyTerminationTests {
  @Test("sax early termination null") func saxEarlyTerminationNull() {
    struct StoppingHandler: JSONSAXEventHandler {
      final class State {
        var didCall = false
      }
      private let _state = State()
      var didCall: Bool { _state.didCall }

      func null() -> Bool {
        _state.didCall = true
        return false
      }

      func boolean(_: Bool) -> Bool { return true }

      func integer(_: Int64) -> Bool { return true }

      func float(_: Double, string _: String) -> Bool { return true }

      func string(_: String) -> Bool { return true }

      func startObject() -> Bool { return true }

      func key(_: String) -> Bool { return true }

      func endObject() -> Bool { return true }

      func startArray() -> Bool { return true }

      func endArray() -> Bool { return true }

      func parseError(_: JSONParseError, data _: Data) -> Bool { return true }
    }
    let handler = StoppingHandler()
    let ok = JSON.parse("null", handler: handler)
    #expect(ok == false)
    #expect(handler.didCall)
  }

  @Test("sax early termination stop parsing") func saxEarlyTerminationStopParsing() {
    struct StoppingHandler: JSONSAXEventHandler {
      func null() -> Bool { return true }

      func boolean(_: Bool) -> Bool { return true }

      func integer(_: Int64) -> Bool { return true }

      func float(_: Double, string _: String) -> Bool { return true }

      func string(_: String) -> Bool { return true }

      func startObject() -> Bool { return true }

      func key(_: String) -> Bool { return false }

      func endObject() -> Bool { return true }

      func startArray() -> Bool { return true }

      func endArray() -> Bool { return true }

      func parseError(_: JSONParseError, data _: Data) -> Bool { return true }
    }
    let handler = StoppingHandler()
    let ok = JSON.parse(#"{"key": "value"}"#, handler: handler)
    #expect(ok == false)
  }
}
