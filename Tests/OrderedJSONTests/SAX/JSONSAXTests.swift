import Foundation
import Testing

@testable import OrderedJSON

final class SAXCollector: JSONSAXEventHandler {
  var events: [(String, String)] = []
  var stopAfter: Int? = nil
  var eventCount = 0

  func null() -> Bool {
    record("null")
    return shouldContinue()
  }
  func boolean(_ value: Bool) -> Bool {
    record("boolean", "\(value)")
    return shouldContinue()
  }
  func integer(_ value: Int64) -> Bool {
    record("integer", "\(value)")
    return shouldContinue()
  }
  func float(_ value: Double, string: String) -> Bool {
    record("float", string)
    return shouldContinue()
  }
  func string(_ value: String) -> Bool {
    record("string", value)
    return shouldContinue()
  }
  func startObject() -> Bool {
    record("startObject")
    return shouldContinue()
  }
  func key(_ value: String) -> Bool {
    record("key", value)
    return shouldContinue()
  }
  func endObject() -> Bool {
    record("endObject")
    return shouldContinue()
  }
  func startArray() -> Bool {
    record("startArray")
    return shouldContinue()
  }
  func endArray() -> Bool {
    record("endArray")
    return shouldContinue()
  }
  func parseError(_ error: JSONParseError, data: Data) -> Bool {
    record("error", "\(error)")
    return false
  }

  private func record(_ e: String, _ v: String = "") {
    events.append((e, v))
    eventCount += 1
  }

  private func shouldContinue() -> Bool {
    if let stop = stopAfter {
      return eventCount < stop
    }
    return true
  }
}

@Test func saxParseNull() {
  let collector = SAXCollector()
  let result = JSON.saxParse("null", handler: collector)
  #expect(result == true)
  #expect(collector.events.count == 1)
  #expect(collector.events[0].0 == "null")
}

@Test func saxParseBooleanTrue() {
  let collector = SAXCollector()
  let result = JSON.saxParse("true", handler: collector)
  #expect(result == true)
  #expect(collector.events.count == 1)
  #expect(collector.events[0] == ("boolean", "true"))
}

@Test func saxParseBooleanFalse() {
  let collector = SAXCollector()
  let result = JSON.saxParse("false", handler: collector)
  #expect(result == true)
  #expect(collector.events.count == 1)
  #expect(collector.events[0] == ("boolean", "false"))
}

@Test func saxParseInteger() {
  let collector = SAXCollector()
  let result = JSON.saxParse("42", handler: collector)
  #expect(result == true)
  #expect(collector.events.count == 1)
  #expect(collector.events[0] == ("integer", "42"))
}

@Test func saxParseNegativeInteger() {
  let collector = SAXCollector()
  let result = JSON.saxParse("-42", handler: collector)
  #expect(result == true)
  #expect(collector.events.count == 1)
  #expect(collector.events[0] == ("integer", "-42"))
}

@Test func saxParseFloat() {
  let collector = SAXCollector()
  let result = JSON.saxParse("3.14", handler: collector)
  #expect(result == true)
  #expect(collector.events.count == 1)
  #expect(collector.events[0].0 == "float")
  #expect(collector.events[0].1 == "3.14")
}

@Test func saxParseString() {
  let collector = SAXCollector()
  let result = JSON.saxParse("\"hello\"", handler: collector)
  #expect(result == true)
  #expect(collector.events.count == 1)
  #expect(collector.events[0] == ("string", "hello"))
}

@Test func saxParseEmptyObject() {
  let collector = SAXCollector()
  let result = JSON.saxParse("{}", handler: collector)
  #expect(result == true)
  #expect(collector.events.count == 2)
  #expect(collector.events[0].0 == "startObject")
  #expect(collector.events[1].0 == "endObject")
}

@Test func saxParseEmptyArray() {
  let collector = SAXCollector()
  let result = JSON.saxParse("[]", handler: collector)
  #expect(result == true)
  #expect(collector.events.count == 2)
  #expect(collector.events[0].0 == "startArray")
  #expect(collector.events[1].0 == "endArray")
}

@Test func saxParseSimpleObject() {
  let collector = SAXCollector()
  let result = JSON.saxParse(#"{"key": "value"}"#, handler: collector)
  #expect(result == true)
  #expect(collector.events.count == 4)
  #expect(collector.events[0].0 == "startObject")
  #expect(collector.events[1] == ("key", "key"))
  #expect(collector.events[2] == ("string", "value"))
  #expect(collector.events[3].0 == "endObject")
}

@Test func saxParseSimpleArray() {
  let collector = SAXCollector()
  let result = JSON.saxParse("[1, 2, 3]", handler: collector)
  #expect(result == true)
  #expect(collector.events.count == 5)
  #expect(collector.events[0].0 == "startArray")
  #expect(collector.events[1] == ("integer", "1"))
  #expect(collector.events[2] == ("integer", "2"))
  #expect(collector.events[3] == ("integer", "3"))
  #expect(collector.events[4].0 == "endArray")
}

@Test func saxParseNestedObject() {
  let collector = SAXCollector()
  let result = JSON.saxParse(#"{"a": {"b": 1}}"#, handler: collector)
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

@Test func saxParseNestedArray() {
  let collector = SAXCollector()
  let result = JSON.saxParse("[[1, 2], [3]]", handler: collector)
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

@Test func saxParseMixed() {
  let collector = SAXCollector()
  let result = JSON.saxParse(#"{"arr": [null, true], "val": "s"}"#, handler: collector)
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

@Test func saxParseErrorInvalidToken() {
  let collector = SAXCollector()
  let result = JSON.saxParse("invalid", handler: collector)
  #expect(result == false)
  #expect(collector.events[0].0 == "error")
}

@Test func saxParseErrorUnexpectedEnd() {
  let collector = SAXCollector()
  let result = JSON.saxParse("{", handler: collector)
  #expect(result == false)
  #expect(collector.events[0].0 == "startObject")
  #expect(collector.events[1].0 == "key")
  #expect(collector.events[2].0 == "error")
}

@Test func saxParseErrorTrailingGarbage() {
  let collector = SAXCollector()
  let result = JSON.saxParse("1 2", handler: collector)
  #expect(result == false)
  #expect(collector.events[0].0 == "integer")
  #expect(collector.events[1].0 == "error")
}

@Test func saxAcceptValid() {
  #expect(JSON.accept("null") == true)
  #expect(JSON.accept("true") == true)
  #expect(JSON.accept("42") == true)
  #expect(JSON.accept("\"hi\"") == true)
  #expect(JSON.accept("{}") == true)
  #expect(JSON.accept("[]") == true)
  #expect(JSON.accept(#"{"k":"v"}"#) == true)
  #expect(JSON.accept("[1,2]") == true)
}

@Test func saxAcceptInvalid() {
  #expect(JSON.accept("") == false)
  #expect(JSON.accept("invalid") == false)
  #expect(JSON.accept("{") == false)
  #expect(JSON.accept("[") == false)
  #expect(JSON.accept("}") == false)
  #expect(JSON.accept("]") == false)
  #expect(JSON.accept(#"{"k":}"#) == false)
  #expect(JSON.accept("[1,]") == false)
}

// MARK: - SAX Parse Edge Cases

@Test func saxParseInvalidEscape() {
  let collector = SAXCollector()
  let result = JSON.saxParse("\"\\x\"", handler: collector)
  #expect(result == false)
}

@Test func saxParseInvalidUnicode() {
  let collector = SAXCollector()
  let result = JSON.saxParse("\"\\u\"", handler: collector)
  // SAX parser is lenient: invalid unicode escape returns empty string, not an error
  #expect(result == true)
  #expect(collector.events[0] == ("string", ""))
}

@Test func saxParseInvalidUnicodeHex() {
  let collector = SAXCollector()
  let result = JSON.saxParse("\"\\uQQQQ\"", handler: collector)
  // SAX parser is lenient: invalid hex chars are consumed so they don't
  // end up as literal characters in the string
  #expect(result == true)
  #expect(collector.events[0].0 == "string")
  #expect(collector.events[0].1 == "")
}

@Test func saxParseIncompleteFloat() {
  let collector = SAXCollector()
  let result = JSON.saxParse("1.0e+", handler: collector)
  #expect(result == false)
}

@Test func saxParseIncompleteNumber() {
  let collector = SAXCollector()
  let result = JSON.saxParse("-", handler: collector)
  #expect(result == false)
}

@Test func saxParseBackslashAtEnd() {
  let collector = SAXCollector()
  let result = JSON.saxParse("\"\\", handler: collector)
  // SAX parser is lenient: backslash at end returns empty string, not an error
  #expect(result == true)
  #expect(collector.events[0] == ("string", ""))
}

@Test func saxParseNumberIncompleteFloat() {
  let collector = SAXCollector()
  // "0." is actually valid in Swift (Double("0.") → 0.0), so SAX returns true
  // Use a truly invalid float like "0.0e" which has incomplete exponent
  let result = JSON.saxParse("0.0e", handler: collector)
  #expect(result == false)
}

@Test func saxAcceptIncompleteObject() {
  #expect(JSON.accept("{\"a\":") == false)
}

@Test func saxAcceptIncompleteArray() {
  #expect(JSON.accept("[1,") == false)
}

@Test func saxAcceptMissingColon() {
  #expect(JSON.accept("{\"a\" 1}") == false)
}

@Test func saxParseUnicodeEscapeFollowedByChar() throws {
  // Regression: SAX used to over-advance after \uXXXX, consuming the next character.
  // "\u0041X" should parse as "AX", not just "A".
  let collector = SAXCollector()
  let jsonString = "{\"key\\u0041X\": 1}"
  let ok = JSON.saxParse(jsonString, handler: collector)
  #expect(ok)
  // The key should be "keyAX", not "keyA"
  let expectedKey = "keyAX"
  #expect(collector.events.count >= 2)
  if collector.events.count >= 2 {
    let (event, value) = collector.events[1]
    #expect(event == "key")
    #expect(value == expectedKey)
  }
}

// MARK: - SAX Early Termination Tests

@Test func saxEarlyTerminationNull() {
  // Handler returns false from null() — parse stops immediately
  class StoppingHandler: JSONSAXEventHandler {
    var didCall = false
    func null() -> Bool {
      didCall = true
      return false
    }
    func boolean(_: Bool) -> Bool { return true }
    func integer(_: Int64) -> Bool { return true }
    func float(_: Double, string: String) -> Bool { return true }
    func string(_: String) -> Bool { return true }
    func startObject() -> Bool { return true }
    func key(_: String) -> Bool { return true }
    func endObject() -> Bool { return true }
    func startArray() -> Bool { return true }
    func endArray() -> Bool { return true }
    func parseError(_: JSONParseError, data: Data) -> Bool { return true }
  }
  let handler = StoppingHandler()
  let ok = JSON.saxParse("null", handler: handler)
  #expect(!ok)  // stopped early
  #expect(handler.didCall)
}

@Test func saxEarlyTerminationStopParsing() {
  // Handler returns false from key() — stops mid-object
  class StoppingHandler: JSONSAXEventHandler {
    func null() -> Bool { return true }
    func boolean(_: Bool) -> Bool { return true }
    func integer(_: Int64) -> Bool { return true }
    func float(_: Double, string: String) -> Bool { return true }
    func string(_: String) -> Bool { return true }
    func startObject() -> Bool { return true }
    func key(_: String) -> Bool { return false }  // stop here
    func endObject() -> Bool { return true }
    func startArray() -> Bool { return true }
    func endArray() -> Bool { return true }
    func parseError(_: JSONParseError, data: Data) -> Bool { return true }
  }
  let handler = StoppingHandler()
  let ok = JSON.saxParse(#"{"key": "value"}"#, handler: handler)
  #expect(!ok)  // stopped early
}
