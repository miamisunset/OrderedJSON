import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - JSONCore Tests

@Suite("Core Tests") struct JSONCoreTests {
  @Test("factory object") func factoryObject() {
    let obj = JSON.object(["a": JSON.string("x")])
    #expect(obj.isObject)
    #expect(obj["a"] == JSON.string("x"))
  }

  @Test("factory array") func factoryArray() {
    let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    #expect(arr.isArray)
    #expect(arr.count == 2)
  }

  @Test("factory string") func factoryString() {
    #expect(JSON.string("hello").isString)
    #expect(JSON.string("hello").stringValue == "hello")
  }

  @Test("factory number") func factoryNumber() {
    #expect(JSON.number(.integer(42)).isNumber)
    #expect(JSON.number(.float(3.14)).isNumber)
  }

  @Test("factory boolean") func factoryBoolean() {
    #expect(JSON.boolean(true).isBoolean)
    #expect(JSON.boolean(false).isBoolean)
  }

  @Test("factory null") func factoryNull() {
    #expect(JSON.null.isNull)
  }

  @Test("convenience init string") func convenienceInitString() {
    let j = JSON("hello")
    #expect(j.isString)
    #expect(j.stringValue == "hello")
  }

  @Test("convenience init bool") func convenienceInitBool() {
    let j = JSON(true)
    #expect(j.isBoolean)
    #expect(j == JSON.boolean(true))
  }

  @Test("convenience init int64") func convenienceInitInt64() {
    let j = JSON(Int64(42))
    #expect(j.isNumber)
    #expect(j.isInteger)
  }

  @Test("convenience init int") func convenienceInitInt() {
    let j = JSON(42)
    #expect(j.isNumber)
    #expect(j.isInteger)
  }

  @Test("convenience init double") func convenienceInitDouble() {
    let j = JSON(3.14)
    #expect(j.isNumber)
    #expect(j.isFloat)
  }

  @Test("convenience init array") func convenienceInitArray() {
    let arr = [JSON.string("a"), JSON.number(.integer(1))]
    let j = JSON(arr)
    #expect(j.isArray)
    #expect(j.count == 2)
  }

  @Test("convenience init object") func convenienceInitObject() {
    let dict = OrderedDictionary<String, JSON>(uniqueKeysWithValues: [("a", JSON.string("x"))])
    let j = JSON(dict)
    #expect(j.isObject)
  }

  @Test("type checks all types") func typeChecksAllTypes() {
    let cases: [(JSON, String, Bool)] = [
      (JSON.null, "null", true),
      (JSON.boolean(true), "boolean", true),
      (JSON.number(.integer(42)), "number", true),
      (JSON.number(.float(3.14)), "number", true),
      (JSON.string("hello"), "string", true),
      (JSON.object(["a": JSON.string("x")]), "object", true),
      (JSON.array([JSON.string("a")]), "array", true),
    ]
    for (val, _, _) in cases {
      #expect(val.isNull == (val == JSON.null))
      #expect(val.isBoolean == (val == JSON.boolean(true) || val == JSON.boolean(false)))
      #expect(
        val.isNumber
          == (val.isNull == false && val.isBoolean == false && val.isString == false
            && val.isObject == false && val.isArray == false)
      )
    }
  }

  @Test("type checks integer vs float") func typeChecksIntegerVsFloat() {
    let intVal = JSON.number(.integer(42))
    let floatVal = JSON.number(.float(42.0))
    #expect(intVal.isInteger)
    #expect(intVal.isFloat == false)
    #expect(floatVal.isInteger == false)
    #expect(floatVal.isFloat)
  }

  @Test("type primitive vs structured") func typePrimitiveVsStructured() {
    #expect(JSON.null.isPrimitive)
    #expect(JSON.boolean(true).isPrimitive)
    #expect(JSON.number(.integer(1)).isPrimitive)
    #expect(JSON.string("hello").isPrimitive)
    #expect(JSON.object([:]).isPrimitive == false)
    #expect(JSON.array([]).isPrimitive == false)

    #expect(JSON.null.isStructured == false)
    #expect(JSON.boolean(true).isStructured == false)
    #expect(JSON.number(.integer(1)).isStructured == false)
    #expect(JSON.string("hello").isStructured == false)
    #expect(JSON.object([:]).isStructured)
    #expect(JSON.array([]).isStructured)
  }

  @Test("type enum") func typeEnum() {
    #expect(JSON.null.type == .null)
    #expect(JSON.boolean(true).type == .boolean)
    #expect(JSON.number(.integer(42)).type == .number)
    #expect(JSON.string("hello").type == .string)
    #expect(JSON.object([:]).type == .object)
    #expect(JSON.array([]).type == .array)
  }

  @Test("type name") func typeName() {
    #expect(JSON.null.typeName == "null")
    #expect(JSON.boolean(true).typeName == "boolean")
    #expect(JSON.number(.integer(42)).typeName == "number")
    #expect(JSON.string("hello").typeName == "string")
    #expect(JSON.object([:]).typeName == "object")
    #expect(JSON.array([]).typeName == "array")
  }

  @Test("string value nil for non string") func stringValueNilForNonString() {
    #expect(JSON.null.stringValue == nil)
    #expect(JSON.boolean(true).stringValue == nil)
    #expect(JSON.number(.integer(42)).stringValue == nil)
    #expect(JSON.object([:]).stringValue == nil)
    #expect(JSON.array([]).stringValue == nil)
  }

  @Test("hashable different values") func hashableDifferentValues() {
    var seen = Set<JSON>()
    seen.insert(JSON.null)
    seen.insert(JSON.boolean(true))
    seen.insert(JSON.number(.integer(42)))
    seen.insert(JSON.string("hello"))
    seen.insert(JSON.object(["a": JSON.string("x")]))
    seen.insert(JSON.array([JSON.string("a")]))
    #expect(seen.count == 6)
  }

  @Test("hashable same value") func hashableSameValue() {
    var seen = Set<JSON>()
    seen.insert(JSON.string("hello"))
    seen.insert(JSON.string("hello"))
    #expect(seen.count == 1)
  }

  @Test("dump compact") func dumpCompact() {
    #expect(JSON.null.dump(indent: .compact) == "null")
    #expect(JSON.boolean(true).dump(indent: .compact) == "true")
    #expect(JSON.number(.integer(42)).dump(indent: .compact) == "42")
    #expect(JSON.string("hello").dump(indent: .compact) == "\"hello\"")
    #expect(
      JSON.array([JSON.string("a"), JSON.number(.integer(1))]).dump(indent: .compact) == "[\"a\",1]")
    let obj = JSON.object(["a": JSON.string("x")])
    #expect(obj.dump(indent: .compact) == "{\"a\":\"x\"}")
  }

  @Test("dump pretty") func dumpPretty() {
    let obj = JSON.object([
      "a": JSON.string("x"),
      "b": JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))]),
    ])
    let pretty = obj.dump(indent: .spaces(2))
    #expect(pretty.contains("\"a\""))
    #expect(pretty.contains("\"b\""))
    #expect(pretty.contains("\n"))
  }

  @Test("dump pretty empty") func dumpPrettyEmpty() {
    #expect(JSON.object([:]).dump(indent: .spaces(2)) == "{}")
    #expect(JSON.array([]).dump(indent: .spaces(2)) == "[]")
  }

  @Test("dump pretty null") func dumpPrettyNull() {
    #expect(JSON.null.dump(indent: .spaces(2)) == "null")
  }

  @Test("dump pretty bool") func dumpPrettyBool() {
    #expect(JSON.boolean(true).dump(indent: .spaces(2)) == "true")
    #expect(JSON.boolean(false).dump(indent: .spaces(2)) == "false")
  }

  @Test("dump pretty number") func dumpPrettyNumber() {
    #expect(JSON.number(.integer(42)).dump(indent: .spaces(2)) == "42")
    #expect(JSON.number(.float(3.14)).dump(indent: .spaces(2)) == "3.14")
  }

  @Test("dump pretty string") func dumpPrettyString() {
    #expect(JSON.string("hello").dump(indent: .spaces(2)) == "\"hello\"")
  }

  @Test("dump ensure ascii") func dumpEnsureAscii() {
    let val = JSON.string("héllo")
    let ascii = val.dump(indent: .compact, ensureAscii: true)
    #expect(ascii == "\"h\\u00E9llo\"")
  }

  @Test("dump escaped characters") func dumpEscapedCharacters() {
    let val = JSON.string("hello\"\n\t\r\\")
    let dumped = val.dump()
    #expect(dumped == "\"hello\\\"\\n\\t\\r\\\\\"")
  }

  @Test("dump backspace formfeed") func dumpBackspaceFormfeed() {
    let val = JSON.string("\u{8}\u{12}")
    let dumped = val.dump()
    #expect(dumped == "\"\\b\\f\"")
  }

  @Test("dump control characters") func dumpControlCharacters() {
    let val = JSON.string("\u{1}\u{2}")
    let dumped = val.dump()
    #expect(dumped == "\"\\u0001\\u0002\"")
  }
}

// MARK: - JSONError Tests

@Suite("Error Tests") struct JSONErrorTests {
  @Test("error descriptions") func errorDescriptions() {
    let typeErr = JSONError.typeError(expected: "object", actual: "string")
    let keyErr = JSONError.keyNotFound("foo")
    let indexErr = JSONError.indexOutOfBounds(42)
    let invalidStr = JSONError.invalidString
    let expectedObj = JSONError.expectedObject
    let formatError = JSONError.formatError("bad patch")
    #expect(typeErr != keyErr)
    #expect(keyErr != indexErr)
    #expect(invalidStr != expectedObj)
    #expect(formatError != invalidStr)
  }

  @Test("parse error descriptions") func parseErrorDescriptions() {
    let errors: [JSONParseError] = [
      .unexpectedEnd(),
      .unexpectedToken(line: 1, column: 5),
      .expectedString(line: 1, column: 10),
      .expectedColon(line: 1, column: 15),
      .expectedCloseBrace(line: 1, column: 20),
      .expectedCloseBracket(line: 1, column: 25),
      .invalidEscape(line: 1, column: 30),
      .invalidUnicodeEscape(line: 1, column: 35),
      .invalidNumber(line: 1, column: 40),
      .invalidEncoding(),
      .depthExceeded(line: 1, column: 42, depth: 0, maxDepth: 0),
    ]
    for err in errors {
      #expect(err.description.isEmpty == false)
    }
  }

  @Test("invalid string thrown") func invalidStringThrown() throws {
    let error = #expect(throws: JSONPointerError.self) {
      try JSONPointer("foo")
    }
    #expect(error == .invalidSyntax("Pointer must start with '/' or be empty"))
  }

  @Test("expected object not thrown") func expectedObjectNotThrown() {
    let err = JSONError.expectedObject
    #expect(err != JSONError.invalidString)
  }
}

// MARK: - Hashable / Equality Tests

@Suite("Equality Tests") struct JSONEqualityTests {
  @Test("hashable equality") func hashableEquality() {
    #expect(JSON.string("a") == JSON.string("a"))
    #expect(JSON.string("a") != JSON.string("b"))
    #expect(JSON.number(.integer(1)) == JSON.number(.integer(1)))
    #expect(JSON.number(.integer(1)) != JSON.number(.float(1.0)))
    #expect(JSON.boolean(true) == JSON.boolean(true))
    #expect(JSON.boolean(true) != JSON.boolean(false))
    #expect(JSON.null == JSON.null)
    #expect(JSON.string("a") != JSON.null)
  }
}

// MARK: - Value Accessor Tests

@Suite("Value Accessor Tests") struct JSONValueAccessorTests {
  @Test("string value returns string") func stringValueReturnsString() {
    let json = JSON.string("hello")
    #expect(json.stringValue == "hello")
  }

  @Test("string value on non string returns nil") func stringValueOnNonStringReturnsNil() {
    let json = JSON.number(.integer(42))
    #expect(json.stringValue == nil)
  }

  @Test("int value on integer") func intValueOnInteger() {
    let json = JSON.number(.integer(42))
    #expect(json.intValue == 42)
  }

  @Test("int value on clean float") func intValueOnCleanFloat() {
    let json = JSON.number(.float(1.0))
    #expect(json.intValue == 1)
  }

  @Test("int value on float with fraction returns nil") func intValueOnFloatWithFractionReturnsNil()
  {
    let json = JSON.number(.float(1.5))
    #expect(json.intValue == nil)
  }

  @Test("int value on non number returns nil") func intValueOnNonNumberReturnsNil() {
    let json = JSON.string("hello")
    #expect(json.intValue == nil)
  }

  @Test("double value on float") func doubleValueOnFloat() {
    let json = JSON.number(.float(3.14))
    #expect(json.doubleValue == 3.14)
  }

  @Test("double value on integer widens") func doubleValueOnIntegerWidens() {
    let json = JSON.number(.integer(42))
    #expect(json.doubleValue == 42.0)
  }

  @Test("double value on non number returns nil") func doubleValueOnNonNumberReturnsNil() {
    let json = JSON.boolean(true)
    #expect(json.doubleValue == nil)
  }

  @Test("bool value on boolean") func boolValueOnBoolean() {
    let json = JSON.boolean(true)
    #expect(json.boolValue == true)
  }

  @Test("bool value on non boolean returns nil") func boolValueOnNonBooleanReturnsNil() {
    let json = JSON.number(.integer(1))
    #expect(json.boolValue == nil)
  }

  @Test("number value on integer") func numberValueOnInteger() {
    let json = JSON.number(.integer(42))
    #expect(json.numberValue == .integer(42))
  }

  @Test("number value on float") func numberValueOnFloat() {
    let json = JSON.number(.float(1.5))
    #expect(json.numberValue == .float(1.5))
  }

  @Test("number value on non number returns nil") func numberValueOnNonNumberReturnsNil() {
    let json = JSON.string("hello")
    #expect(json.numberValue == nil)
  }
}
