import OrderedCollections
@testable import OrderedJSON
import Testing

// MARK: - JSONCore Tests

@Test func factoryObject() {
    let obj = JSON.object(["a": JSON.string("x")])
    #expect(obj.isObject)
    #expect(obj["a"] == JSON.string("x"))
}

@Test func factoryArray() {
    let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    #expect(arr.isArray)
    #expect(arr.count == 2)
}

@Test func factoryString() {
    #expect(JSON.string("hello").isString)
    #expect(JSON.string("hello").stringValue == "hello")
}

@Test func factoryNumber() {
    #expect(JSON.number(.integer(42)).isNumber)
    #expect(JSON.number(.float(3.14)).isNumber)
}

@Test func factoryBoolean() {
    #expect(JSON.boolean(true).isBoolean)
    #expect(JSON.boolean(false).isBoolean)
}

@Test func factoryNull() {
    #expect(JSON.null.isNull)
    #expect(JSON.nullValue().isNull)
}

@Test func convenienceInitString() {
    let j = JSON("hello")
    #expect(j.isString)
    #expect(j.stringValue == "hello")
}

@Test func convenienceInitBool() {
    let j = JSON(true)
    #expect(j.isBoolean)
    #expect(j == JSON.boolean(true))
}

@Test func convenienceInitInt64() {
    let j = JSON(Int64(42))
    #expect(j.isNumber)
    #expect(j.isInteger)
}

@Test func convenienceInitInt() {
    let j = JSON(42)
    #expect(j.isNumber)
    #expect(j.isInteger)
}

@Test func convenienceInitDouble() {
    let j = JSON(3.14)
    #expect(j.isNumber)
    #expect(j.isFloat)
}

@Test func convenienceInitArray() {
    let arr = [JSON.string("a"), JSON.number(.integer(1))]
    let j = JSON(arr)
    #expect(j.isArray)
    #expect(j.count == 2)
}

@Test func convenienceInitObject() {
    let dict = OrderedDictionary<String, JSON>(uniqueKeysWithValues: [("a", JSON.string("x"))])
    let j = JSON(dict)
    #expect(j.isObject)
}

@Test func typeChecksAllTypes() {
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
                == (!val.isNull && !val.isBoolean && !val.isString && !val.isObject && !val.isArray)
        )
    }
}

@Test func typeChecksIntegerVsFloat() {
    let intVal = JSON.number(.integer(42))
    let floatVal = JSON.number(.float(42.0))
    #expect(intVal.isInteger)
    #expect(!intVal.isFloat)
    #expect(!floatVal.isInteger)
    #expect(floatVal.isFloat)
}

@Test func typePrimitiveVsStructured() {
    #expect(JSON.null.isPrimitive)
    #expect(JSON.boolean(true).isPrimitive)
    #expect(JSON.number(.integer(1)).isPrimitive)
    #expect(JSON.string("hello").isPrimitive)
    #expect(!JSON.object([:]).isPrimitive)
    #expect(!JSON.array([]).isPrimitive)

    #expect(!JSON.null.isStructured)
    #expect(!JSON.boolean(true).isStructured)
    #expect(!JSON.number(.integer(1)).isStructured)
    #expect(!JSON.string("hello").isStructured)
    #expect(JSON.object([:]).isStructured)
    #expect(JSON.array([]).isStructured)
}

@Test func typeEnum() {
    #expect(JSON.null.type == .null)
    #expect(JSON.boolean(true).type == .boolean)
    #expect(JSON.number(.integer(42)).type == .number)
    #expect(JSON.string("hello").type == .string)
    #expect(JSON.object([:]).type == .object)
    #expect(JSON.array([]).type == .array)
}

@Test func typeName() {
    #expect(JSON.null.typeName == "null")
    #expect(JSON.boolean(true).typeName == "boolean")
    #expect(JSON.number(.integer(42)).typeName == "number")
    #expect(JSON.string("hello").typeName == "string")
    #expect(JSON.object([:]).typeName == "object")
    #expect(JSON.array([]).typeName == "array")
}

@Test func stringValueNilForNonString() {
    #expect(JSON.null.stringValue == nil)
    #expect(JSON.boolean(true).stringValue == nil)
    #expect(JSON.number(.integer(42)).stringValue == nil)
    #expect(JSON.object([:]).stringValue == nil)
    #expect(JSON.array([]).stringValue == nil)
}

@Test func hashableDifferentValues() {
    var seen = Set<JSON>()
    seen.insert(JSON.null)
    seen.insert(JSON.boolean(true))
    seen.insert(JSON.number(.integer(42)))
    seen.insert(JSON.string("hello"))
    seen.insert(JSON.object(["a": JSON.string("x")]))
    seen.insert(JSON.array([JSON.string("a")]))
    #expect(seen.count == 6)
}

@Test func hashableSameValue() {
    var seen = Set<JSON>()
    seen.insert(JSON.string("hello"))
    seen.insert(JSON.string("hello"))
    #expect(seen.count == 1)
}

@Test func dumpCompact() {
    #expect(JSON.null.dump(indent: -1) == "null")
    #expect(JSON.boolean(true).dump(indent: -1) == "true")
    #expect(JSON.number(.integer(42)).dump(indent: -1) == "42")
    #expect(JSON.string("hello").dump(indent: -1) == "\"hello\"")
    #expect(JSON.array([JSON.string("a"), JSON.number(.integer(1))]).dump(indent: -1) == "[\"a\",1]")
    let obj = JSON.object(["a": JSON.string("x")])
    #expect(obj.dump(indent: -1) == "{\"a\":\"x\"}")
}

@Test func dumpPretty() {
    let obj = JSON.object([
        "a": JSON.string("x"),
        "b": JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))]),
    ])
    let pretty = obj.dump(indent: 2)
    #expect(pretty.contains("\"a\""))
    #expect(pretty.contains("\"b\""))
    #expect(pretty.contains("\n"))
}

@Test func dumpPrettyEmpty() {
    #expect(JSON.object([:]).dump(indent: 2) == "{}")
    #expect(JSON.array([]).dump(indent: 2) == "[]")
}

@Test func dumpPrettyNull() {
    #expect(JSON.null.dump(indent: 2) == "null")
}

@Test func dumpPrettyBool() {
    #expect(JSON.boolean(true).dump(indent: 2) == "true")
    #expect(JSON.boolean(false).dump(indent: 2) == "false")
}

@Test func dumpPrettyNumber() {
    #expect(JSON.number(.integer(42)).dump(indent: 2) == "42")
    #expect(JSON.number(.float(3.14)).dump(indent: 2) == "3.14")
}

@Test func dumpPrettyString() {
    #expect(JSON.string("hello").dump(indent: 2) == "\"hello\"")
}

@Test func dumpEnsureAscii() {
    let val = JSON.string("héllo")
    let ascii = val.dump(indent: -1, ensureAscii: true)
    #expect(ascii == "\"h\\u00E9llo\"")
}

@Test func dumpEscapedCharacters() {
    let val = JSON.string("hello\"\n\t\r\\")
    let dumped = val.dump(indent: -1)
    #expect(dumped == "\"hello\\\"\\n\\t\\r\\\\\"")
}

@Test func dumpBackspaceFormfeed() {
    let val = JSON.string("\u{8}\u{12}")
    let dumped = val.dump(indent: -1)
    #expect(dumped == "\"\\b\\f\"")
}

@Test func dumpControlCharacters() {
    let val = JSON.string("\u{1}\u{2}")
    let dumped = val.dump(indent: -1)
    #expect(dumped == "\"\\u0001\\u0002\"")
}

// MARK: - JSONError Tests

@Test func jsonErrorDescriptions() {
    let typeErr = JSONError.typeError(expected: "object", actual: "string")
    let keyErr = JSONError.keyNotFound("foo")
    let indexErr = JSONError.indexOutOfBounds(42)
    let invalidStr = JSONError.invalidString
    let expectedObj = JSONError.expectedObject
    let formatError = JSONError.formatError("bad patch")
    // Ensure these compile and are Sendable/Hashable
    #expect(typeErr != keyErr)
    #expect(keyErr != indexErr)
    #expect(invalidStr != expectedObj)
    #expect(formatError != invalidStr)
}

@Test func jsonParseErrorDescriptions() {
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
        #expect(!err.description.isEmpty)
    }
}

@Test func jsonErrorInvalidStringThrown() throws {
    // JSONPointer.init now throws JSONPointerError.invalidSyntax
    #expect {
        try JSONPointer("foo")
    } throws: { error in
        guard let ptrErr = error as? JSONPointerError else { return false }
        return ptrErr == .invalidSyntax("Pointer must start with '/' or be empty")
    }
}

@Test func jsonErrorExpectedObjectNotThrown() {
    // expectedObject is a valid enum case but never thrown in library code
    // Verify it exists and can be compared
    let err = JSONError.expectedObject
    #expect(err != JSONError.invalidString)
}

// MARK: - Hashable / Equality Tests

@Test func hashableEquality() {
    #expect(JSON.string("a") == JSON.string("a"))
    #expect(JSON.string("a") != JSON.string("b"))
    #expect(JSON.number(.integer(1)) == JSON.number(.integer(1)))
    #expect(JSON.number(.integer(1)) != JSON.number(.float(1.0)))
    #expect(JSON.boolean(true) == JSON.boolean(true))
    #expect(JSON.boolean(true) != JSON.boolean(false))
    #expect(JSON.null == JSON.null)
    #expect(JSON.string("a") != JSON.null)
}

// MARK: - Value Accessor Tests

@Test func stringValueReturnsString() {
    let json = JSON.string("hello")
    #expect(json.stringValue == "hello")
}

@Test func stringValueOnNonStringReturnsNil() {
    let json = JSON.number(.integer(42))
    #expect(json.stringValue == nil)
}

@Test func intValueOnInteger() {
    let json = JSON.number(.integer(42))
    #expect(json.intValue == 42)
}

@Test func intValueOnCleanFloat() {
    let json = JSON.number(.float(1.0))
    #expect(json.intValue == 1)
}

@Test func intValueOnFloatWithFractionReturnsNil() {
    let json = JSON.number(.float(1.5))
    #expect(json.intValue == nil)
}

@Test func intValueOnNonNumberReturnsNil() {
    let json = JSON.string("hello")
    #expect(json.intValue == nil)
}

@Test func floatValueOnFloat() {
    let json = JSON.number(.float(3.14))
    #expect(json.floatValue == 3.14)
}

@Test func floatValueOnIntegerWidens() {
    let json = JSON.number(.integer(42))
    #expect(json.floatValue == 42.0)
}

@Test func floatValueOnNonNumberReturnsNil() {
    let json = JSON.boolean(true)
    #expect(json.floatValue == nil)
}

@Test func boolValueOnBoolean() {
    let json = JSON.boolean(true)
    #expect(json.boolValue == true)
}

@Test func boolValueOnNonBooleanReturnsNil() {
    let json = JSON.number(.integer(1))
    #expect(json.boolValue == nil)
}

@Test func numberValueOnInteger() {
    let json = JSON.number(.integer(42))
    #expect(json.numberValue == .integer(42))
}

@Test func numberValueOnFloat() {
    let json = JSON.number(.float(1.5))
    #expect(json.numberValue == .float(1.5))
}

@Test func numberValueOnNonNumberReturnsNil() {
    let json = JSON.string("hello")
    #expect(json.numberValue == nil)
}
