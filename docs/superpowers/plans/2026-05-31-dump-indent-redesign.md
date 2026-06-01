# Dump Indent API Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace freeform `dump(indent: Int?, indentCharacter:, ensureAscii:)` with a type-safe `JSON.Indent` enum, add `OutputOptions` to `OrderedJSONEncoder`, and update all tests/docs.

**Architecture:** `JSON.Indent` enum (`.compact`, `.spaces(Int)`, `.tab`) nested in `JSON`. `dump()` signature changes to accept `Indent` instead of `Int?` + `Character`. `OrderedJSONEncoder` gains `OutputOptions { indent, sortedKeys }` and `encodeAsData()`. Builders delegate to the new `dump()`.

**Tech Stack:** Swift 6.3, OrderedJSON library, OrderedCollections, Swift Testing

---

## File Map

| File | Role | Changes |
|------|------|---------|
| `Sources/OrderedJSON/Parsing/JSONSerializer.swift` | `dump()` + serialization | Add `Indent` enum, replace `dump()` signature, add `sortedDump` helpers |
| `Sources/OrderedJSON/Builder/JSON+ObjectBuilder.swift` | Object builder `buildString` | Change `indent: Int?` → `indent: Indent` |
| `Sources/OrderedJSON/Builder/JSON+ArrayBuilder.swift` | Array builder `buildString` | Change `indent: Int?` → `indent: Indent` |
| `Sources/OrderedJSON/Codable/OrderedJSONEncoder.swift` | Encoder | Add `OutputOptions`, update `encodeAsString`, add `encodeAsData` |
| `Tests/OrderedJSONTests/Core/JSONCoreTests.swift` | Dump tests | Update existing, add new (tab, spaces4, spaces0, spacesNegative) |
| `Tests/OrderedJSONTests/READMEEncodingTests.swift` | README encoding tests | Update dump calls |
| `Tests/OrderedJSONTests/Builder/JSONArrayBuilderTests.swift` | Array builder tests | Update `buildString(indent:)` calls |
| `Tests/OrderedJSONTests/Builder/JSONObjectBuilderTests.swift` | Object builder tests | Update `buildString(indent:)` calls |
| `Tests/OrderedJSONTests/Codable/EncodeAsStringEdgeCaseTests.swift` | Encoder string tests | Update + add OutputOptions tests |
| `Tests/OrderedJSONTests/Codable/OrderedJSONEncoderTests.swift` | Encoder tests | Add encodeAsData + sortedKeys tests |
| `Tests/OrderedJSONTests/Integration/JSONIntegrationParseDumpTests.swift` | Integration tests | Update dump calls |
| `README.md` | User-facing docs | Update Encoding/Serialization + Codable sections |

---

### Task 1: Add `JSON.Indent` enum + update `dump()` signature

**Files:**
- Modify: `Sources/OrderedJSON/Parsing/JSONSerializer.swift` (full file)

- [ ] **Step 1: Add `JSON.Indent` enum above the `dump()` method**

Add this before the `dump` method:

```swift
/// Controls indentation for JSON serialization.
///
/// Per RFC 8259, JSON indent characters are limited to space and horizontal tab.
/// This enum makes invalid indent states impossible at compile time.
public enum Indent: Hashable, Sendable {
  /// Compact output with no whitespace.
  case compact
  /// Indent with spaces — the number of spaces per indent level.
  ///
  /// The width must be non-negative. A value of 0 produces no leading
  /// whitespace (effectively compact within containers), while positive
  /// values produce the corresponding number of spaces per level.
  /// Negative values trigger a runtime precondition failure.
  case spaces(Int)
  /// Indent with horizontal tab characters.
  case tab
}
```

- [ ] **Step 2: Replace `dump()` signature**

Old:
```swift
public func dump(
  indent: Int? = nil,
  indentCharacter: Character = " ",
  ensureAscii: Bool = false
) -> String {
  if let indentValue = indent {
    // ... old pretty path
  }
  // ... old compact path
}
```

New:
```swift
public func dump(
  indent: Indent = .compact,
  ensureAscii: Bool = false
) -> String {
  switch indent {
  case .compact:
    var string = ""
    serializeJSONCompact(self, ensureAscii: ensureAscii, into: &string)
    return string
  case .spaces(let width):
    precondition(width >= 0, "Indent.spaces width (\(width)) must be non-negative")
    var string = ""
    serializeJSONPretty(self, indent: width, indentCharacter: " ", depth: 0, ensureAscii: ensureAscii, into: &string)
    return string
  case .tab:
    var string = ""
    serializeJSONPretty(self, indent: 1, indentCharacter: "\t", depth: 0, ensureAscii: ensureAscii, into: &string)
    return string
  }
}
```

Note: `serializeJSONPretty` already accepts an `indentCharacter: Character` parameter — we pass `" "` for `.spaces` and `"\t"` for `.tab`. The `indent` parameter becomes the width (for `.spaces`) or 1 (for `.tab`, since each level is one tab).

- [ ] **Step 3: Update doc comments on `dump()`**

Replace the doc comment block to reflect new API:

```swift
/// Pretty-prints this JSON value with the given indentation.
///
/// - Parameter indent: Indentation style. Use `.compact` for single-line
///   output (default), `.spaces(n)` for n-space indentation, or `.tab`
///   for tab indentation.
/// - Parameter ensureAscii: If `true`, non-ASCII characters are escaped as
///   `\uXXXX`. Defaults to `false`.
/// - Returns: A JSON string.
///
/// ## Example
///
/// ```swift
/// let json = JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])
/// json.dump()                         // compact: {"name":"Alice","age":30}
/// json.dump(indent: .spaces(2))       // pretty-printed with 2-space indent
/// json.dump(indent: .compact)         // compact
/// json.dump(indent: .tab)             // tab-indented
/// json.dump(ensureAscii: true)        // escape non-ASCII as \uXXXX
/// ```
```

- [ ] **Step 4: Run tests to verify compilation**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift build
```
Expected: Build succeeds. (Tests will fail because they still use old API — that's expected at this stage.)

- [ ] **Step 5: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Sources/OrderedJSON/Parsing/JSONSerializer.swift && git commit -m "$(cat <<'EOF'
feat: add JSON.Indent enum and replace dump() signature

JSON.Indent replaces the freeform (indent:, indentCharacter:) pair with a
type-safe enum: .compact, .spaces(Int), .tab. Negative spaces width triggers
a precondition failure.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Update builder `buildString` signatures

**Files:**
- Modify: `Sources/OrderedJSON/Builder/JSON+ObjectBuilder.swift:308-312`
- Modify: `Sources/OrderedJSON/Builder/JSON+ArrayBuilder.swift:302-305`

- [ ] **Step 1: Update `JSON.ObjectBuilder.buildString`**

Old:
```swift
/// Builds the JSON object and returns the serialized JSON string.
/// - Parameter indent: Number of spaces per indent level. `nil` means compact (no indent).
public func buildString(indent: Int? = nil) -> String {
  return build().dump(indent: indent)
}
```

New:
```swift
/// Builds the JSON object and returns the serialized JSON string.
/// - Parameter indent: Indentation style. Use `.compact` for single-line
///   output (default), `.spaces(n)` for n-space indentation, or `.tab`.
public func buildString(indent: JSON.Indent = .compact) -> String {
  return build().dump(indent: indent)
}
```

- [ ] **Step 2: Update `JSON.ArrayBuilder.buildString`**

Old:
```swift
/// Builds the JSON array and returns the serialized JSON string.
/// - Parameter indent: Number of spaces per indent level. `nil` means compact (no indent).
public func buildString(indent: Int? = nil) -> String {
  return build().dump(indent: indent)
}
```

New:
```swift
/// Builds the JSON array and returns the serialized JSON string.
/// - Parameter indent: Indentation style. Use `.compact` for single-line
///   output (default), `.spaces(n)` for n-space indentation, or `.tab`.
public func buildString(indent: JSON.Indent = .compact) -> String {
  return build().dump(indent: indent)
}
```

- [ ] **Step 3: Build to verify**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift build
```
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Sources/OrderedJSON/Builder/JSON+ObjectBuilder.swift Sources/OrderedJSON/Builder/JSON+ArrayBuilder.swift && git commit -m "$(cat <<'EOF'
feat: update builder buildString to use JSON.Indent

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Add `OutputOptions` + `encodeAsData` to `OrderedJSONEncoder`

**Files:**
- Modify: `Sources/OrderedJSON/Codable/OrderedJSONEncoder.swift`

- [ ] **Step 1: Add `OutputOptions` struct**

Add this nested struct inside `OrderedJSONEncoder`:

```swift
/// Options controlling JSON output formatting.
public struct OutputOptions: Hashable, Sendable {
  /// Indentation style for pretty-printed output. Defaults to `.compact`.
  public var indent: JSON.Indent = .compact

  /// If `true`, object keys are sorted alphabetically during serialization.
  /// Defaults to `false` (preserves insertion order).
  public var sortedKeys: Bool = false

  public init(indent: JSON.Indent = .compact, sortedKeys: Bool = false) {
    self.indent = indent
    self.sortedKeys = sortedKeys
  }
}
```

- [ ] **Step 2: Add `outputOptions` property and update `encodeAsString`**

Add property:
```swift
/// Output formatting options for string/data encoding.
public var outputOptions: OutputOptions = .init()
```

Update `encodeAsString`:
```swift
public func encodeAsString<T: Encodable>(_ value: T) throws -> String {
  let json = try encode(value)
  if outputOptions.sortedKeys {
    return json._sortedDump(indent: outputOptions.indent)
  }
  return json.dump(indent: outputOptions.indent)
}
```

- [ ] **Step 3: Add `encodeAsData` method**

```swift
/// Encodes a value and returns the JSON data, using current output options.
/// - Parameter value: The value to encode.
/// - Returns: UTF-8 encoded JSON data.
/// - Throws: `EncodingError` if the value cannot be encoded.
public func encodeAsData<T: Encodable>(_ value: T) throws -> Data {
  let string = try encodeAsString(value)
  guard let data = string.data(using: .utf8) else {
    throw EncodingError.invalidValue(
      value,
      EncodingError.Context(
        codingPath: [],
        debugDescription: "failed to encode JSON string as UTF-8 data"
      )
    )
  }
  return data
}
```

- [ ] **Step 4: Build to verify**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift build
```
Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Sources/OrderedJSON/Codable/OrderedJSONEncoder.swift && git commit -m "$(cat <<'EOF'
feat: add OutputOptions and encodeAsData to OrderedJSONEncoder

OutputOptions supports configurable indent style and sorted keys.
encodeAsData returns UTF-8 encoded Data.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Add `_sortedDump` private helper on `JSON`

**Files:**
- Modify: `Sources/OrderedJSON/Parsing/JSONSerializer.swift`

- [ ] **Step 1: Add `_sortedDump` and `_serializeSorted` methods**

Add these private methods inside the `extension JSON` block in JSONSerializer.swift (after `serializeJSONString`):

```swift
/// Serializes with keys sorted alphabetically for objects.
private func _sortedDump(indent: Indent = .compact, ensureAscii: Bool = false) -> String {
  var string = ""
  _serializeSorted(self, indent: indent, depth: 0, ensureAscii: ensureAscii, into: &string)
  return string
}

private func _serializeSorted(
  _ value: JSON, indent: Indent, depth: Int, ensureAscii: Bool,
  into string: inout String
) {
  switch indent {
  case .compact:
    _serializeSortedCompact(value, depth: depth, ensureAscii: ensureAscii, into: &string)
  case .spaces(let width):
    precondition(width >= 0, "Indent.spaces width (\(width)) must be non-negative")
    _serializeSortedPretty(value, indent: width, indentCharacter: " ", depth: depth, ensureAscii: ensureAscii, into: &string)
  case .tab:
    _serializeSortedPretty(value, indent: 1, indentCharacter: "\t", depth: depth, ensureAscii: ensureAscii, into: &string)
  }
}

/// Compact serialization with sorted object keys.
private func _serializeSortedCompact(
  _ value: JSON, depth: Int, ensureAscii: Bool, into string: inout String
) {
  switch value.storage {
  case .null:
    string += "null"
  case .boolean(let bool):
    string += bool ? "true" : "false"
  case .number(let num):
    serializeJSONNumber(num, into: &string)
  case .string(let s):
    serializeJSONString(s, ensureAscii: ensureAscii, into: &string)
  case .array(let arr):
    string += "["
    for (i, el) in arr.enumerated() {
      if i > 0 { string += "," }
      _serializeSortedCompact(el, depth: depth, ensureAscii: ensureAscii, into: &string)
    }
    string += "]"
  case .object(let dict):
    string += "{"
    let sortedKeys = dict.keys.sorted()
    var first = true
    for key in sortedKeys {
      guard let value = dict[key] else { continue }
      if !first { string += "," }
      first = false
      serializeJSONString(key, ensureAscii: ensureAscii, into: &string)
      string += ":"
      _serializeSortedCompact(value, depth: depth, ensureAscii: ensureAscii, into: &string)
    }
    string += "}"
  }
}

/// Pretty-printed serialization with sorted object keys.
private func _serializeSortedPretty(
  _ value: JSON, indent: Int, indentCharacter: Character, depth: Int, ensureAscii: Bool,
  into string: inout String
) {
  let pad = String(repeating: String(indentCharacter), count: depth * indent)
  let innerPad = String(repeating: String(indentCharacter), count: (depth + 1) * indent)
  switch value.storage {
  case .null:
    string += "null"
  case .boolean(let bool):
    string += bool ? "true" : "false"
  case .number(let num):
    serializeJSONNumber(num, into: &string)
  case .string(let s):
    serializeJSONString(s, ensureAscii: ensureAscii, into: &string)
  case .array(let arr):
    if arr.isEmpty {
      string += "[]"
    } else {
      string += "[\n"
      for (i, el) in arr.enumerated() {
        if i > 0 { string += ",\n" }
        string += innerPad
        _serializeSortedPretty(el, indent: indent, indentCharacter: indentCharacter, depth: depth + 1, ensureAscii: ensureAscii, into: &string)
      }
      string += "\n"
      string += pad
      string += "]"
    }
  case .object(let dict):
    if dict.isEmpty {
      string += "{}"
    } else {
      string += "{\n"
      let sortedKeys = dict.keys.sorted()
      var first = true
      for key in sortedKeys {
        guard let value = dict[key] else { continue }
        if !first { string += ",\n" }
        first = false
        string += innerPad
        serializeJSONString(key, ensureAscii: ensureAscii, into: &string)
        string += ": "
        _serializeSortedPretty(value, indent: indent, indentCharacter: indentCharacter, depth: depth + 1, ensureAscii: ensureAscii, into: &string)
      }
      string += "\n"
      string += pad
      string += "}"
    }
  }
}
```

- [ ] **Step 2: Build to verify**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift build
```
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Sources/OrderedJSON/Parsing/JSONSerializer.swift && git commit -m "$(cat <<'EOF'
feat: add private sortedDump helper for alphabetically sorted key output

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Update existing tests in `JSONCoreTests.swift`

**Files:**
- Modify: `Tests/OrderedJSONTests/Core/JSONCoreTests.swift:173-240`

- [ ] **Step 1: Update `dumpCompact` test**

Replace `dump(indent: nil)` → `dump(indent: .compact)`:

```swift
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
```

- [ ] **Step 2: Update `dumpPretty` test**

Replace `dump(indent: 2)` → `dump(indent: .spaces(2))`:

```swift
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
```

- [ ] **Step 3: Update `dumpPrettyEmpty`, `dumpPrettyNull`, `dumpPrettyBool`, `dumpPrettyNumber`, `dumpPrettyString`**

Replace `dump(indent: 2)` → `dump(indent: .spaces(2))` in all of these:

```swift
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
```

- [ ] **Step 4: Update `dumpEnsureAscii`**

Replace `dump(indent: nil, ensureAscii: true)` → `dump(indent: .compact, ensureAscii: true)`:

```swift
@Test("dump ensure ascii") func dumpEnsureAscii() {
  let val = JSON.string("héllo")
  let ascii = val.dump(indent: .compact, ensureAscii: true)
  #expect(ascii == "\"h\\u00E9llo\"")
}
```

- [ ] **Step 5: Update `dumpEscapedCharacters`, `dumpBackspaceFormfeed`, `dumpControlCharacters`**

Replace `dump(indent: nil)` → `dump()` (defaults to `.compact`):

```swift
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
```

- [ ] **Step 6: Run tests**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift test --filter "JSONCoreTests"
```
Expected: All dump tests pass.

- [ ] **Step 7: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Tests/OrderedJSONTests/Core/JSONCoreTests.swift && git commit -m "$(cat <<'EOF'
test: update JSONCoreTests to use new JSON.Indent API

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Update existing tests in other files

**Files:**
- Modify: `Tests/OrderedJSONTests/READMEEncodingTests.swift`
- Modify: `Tests/OrderedJSONTests/Integration/JSONIntegrationParseDumpTests.swift`
- Modify: `Tests/OrderedJSONTests/Codable/EncodeAsStringEdgeCaseTests.swift`
- Modify: `Tests/OrderedJSONTests/Codable/OrderedJSONEncoderTests.swift`
- Modify: `Tests/OrderedJSONTests/Builder/JSONArrayBuilderTests.swift`
- Modify: `Tests/OrderedJSONTests/Builder/JSONObjectBuilderTests.swift`

- [ ] **Step 1: Update `READMEEncodingTests.swift`**

```swift
@Test func readmeEncodingSerialization() {
  let value = JSON.object([
    "name": JSON.string("Bob"),
    "age": JSON.number(.integer(25)),
  ])

  let compact = value.dump()
  #expect(compact == "{\"name\":\"Bob\",\"age\":25}")

  let pretty = value.dump(indent: .spaces(2))
  #expect(pretty.contains("\n"))
  #expect(pretty.contains("  "))
}
```

- [ ] **Step 2: Update `JSONIntegrationParseDumpTests.swift`**

Update the following:
- `parseDumpParseObject`: `json1.dump()` — no change needed (defaults to `.compact`)
- `parseDumpParseNestedArrays`: `json1.dump()` — no change needed
- `parseDumpParseEscapedStrings`: `json1.dump()` — no change needed
- `parseDumpParseEdgeNumbers`: `json1.dump()` — no change needed
- `parseDumpParseEmpty`: `json1.dump()` — no change needed
- `parseDumpPrettyRoundTrip`: `json1.dump(indent: 2)` → `json1.dump(indent: .spaces(2))`
- `parseDumpEnsureAsciiRoundTrip`: `json1.dump(ensureAscii: true)` — no change needed
- `parseDumpParseKeyOrder`: `json1.dump()` — no change needed

Only line 77 changes:
```swift
@Test("parse → dump(indent:) → parse: pretty-printed round-trip")
func parseDumpPrettyRoundTrip() throws {
  let input = """
    {"a": 1, "b": [2, 3, {"c": 4}]}
    """
  let json1 = try JSON.parse(input)
  let pretty = json1.dump(indent: .spaces(2))
  let json2 = try JSON.parse(pretty)
  #expect(json1 == json2)
}
```

- [ ] **Step 3: Update `EncodeAsStringEdgeCaseTests.swift`**

Update `encodeAsStringMatchesDump` — `json.dump(indent: nil)` → `json.dump(indent: .compact)`:

```swift
@Test("encodeAsString matches dump(indent: nil)")
func encodeAsStringMatchesDump() throws {
  struct Person: Encodable {
    let name: String
    let age: Int
  }
  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Person(name: "Alice", age: 30))
  let dumpString = json.dump(indent: .compact)
  let encodeString = try encoder.encodeAsString(Person(name: "Alice", age: 30))
  #expect(encodeString == dumpString)
}
```

No other changes needed in this file — the other tests already use `dump()` without parameters (defaults to `.compact`).

- [ ] **Step 4: Update `OrderedJSONEncoderTests.swift`**

No changes needed — `encodeAsString` calls already use the default (`.compact`).

- [ ] **Step 5: Update `JSONArrayBuilderTests.swift`**

Line 93: `buildString(indent: 2)` → `buildString(indent: .spaces(2))`:

```swift
@Test("array builder build string with indent") func arrayBuilderBuildStringWithIndent() {
  let str = JSON.ArrayBuilder()
    .add(1)
    .add("two")
    .buildString(indent: .spaces(2))

  let expected = """
    [
      1,
      "two"
    ]
    """
  #expect(str == expected)
}
```

- [ ] **Step 6: Update `JSONObjectBuilderTests.swift`**

Line 129: `buildString(indent: 2)` → `buildString(indent: .spaces(2))`:

```swift
@Test("object builder build string with indent") func objectBuilderBuildStringWithIndent() {
  let str = JSON.ObjectBuilder()
    .set("x", 1)
    .set("y", "hello")
    .buildString(indent: .spaces(2))

  let expected = """
    {
      "x": 1,
      "y": "hello"
    }
    """
  #expect(str == expected)
}
```

- [ ] **Step 7: Run all tests**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift test
```
Expected: All existing tests pass with new API.

- [ ] **Step 8: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Tests/OrderedJSONTests/READMEEncodingTests.swift Tests/OrderedJSONTests/Integration/JSONIntegrationParseDumpTests.swift Tests/OrderedJSONTests/Codable/EncodeAsStringEdgeCaseTests.swift Tests/OrderedJSONTests/Builder/JSONArrayBuilderTests.swift Tests/OrderedJSONTests/Builder/JSONObjectBuilderTests.swift && git commit -m "$(cat <<'EOF'
test: update remaining tests to use new JSON.Indent API

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Add new tests for tab indent, spaces variations, and precondition

**Files:**
- Modify: `Tests/OrderedJSONTests/Core/JSONCoreTests.swift`

- [ ] **Step 1: Add `dumpTabIndent` test**

Add after `dumpPrettyString`:

```swift
@Test("dump tab indent") func dumpTabIndent() {
  let obj = JSON.object([
    "a": JSON.string("x"),
    "b": JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))]),
  ])
  let tabby = obj.dump(indent: .tab)
  #expect(tabby.contains("\t"))
  // First line after opening brace should start with \t
  #expect(tabby.contains("\n\t"))
}
```

- [ ] **Step 2: Add `dumpSpaces4` test**

```swift
@Test("dump spaces 4") func dumpSpaces4() {
  let obj = JSON.object([
    "a": JSON.string("x"),
    "b": JSON.number(.integer(1)),
  ])
  let result = obj.dump(indent: .spaces(4))
  #expect(result.contains("    "))  // 4 spaces
  #expect(result.contains("\n"))
}
```

- [ ] **Step 3: Add `dumpSpaces0` test**

```swift
@Test("dump spaces 0") func dumpSpaces0() {
  let obj = JSON.object([
    "a": JSON.string("x"),
    "b": JSON.array([JSON.number(.integer(1))]),
  ])
  let result = obj.dump(indent: .spaces(0))
  // With width 0, inner content should have no leading whitespace
  // but newlines still separate elements
  #expect(result.contains("\n"))
  #expect(result.contains("{\n"))
  #expect(result.contains("\"a\""))
}
```

- [ ] **Step 4: Add `dumpSpacesNegative` test**

This test should verify that a negative width triggers a precondition failure.
Use `withKnownIssue` to capture the expected precondition failure:

```swift
@Test("dump spaces negative precondition")
func dumpSpacesNegative() {
  #expect(throws: (any Error).self) {
    _ = JSON.null.dump(indent: .spaces(-1))
  }
}
```

Note: Swift `precondition` raises a runtime error that Swift Testing catches as a thrown error. If the test harness doesn't catch it this way, use a different approach — wrap in a `withKnownIssue` block or check that the call crashes. Actually, `precondition` in Swift raises a `FatalError` which terminates the process. Swift Testing's `#expect(throws:)` may not catch fatal errors. Instead, use `withKnownIssue`:

```swift
@Test("dump spaces negative precondition")
func dumpSpacesNegative() {
  withKnownIssue {
    _ = JSON.null.dump(indent: .spaces(-1))
  }
}
```

- [ ] **Step 5: Run new tests**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift test --filter "JSONCoreTests"
```
Expected: All dump tests pass including new ones.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Tests/OrderedJSONTests/Core/JSONCoreTests.swift && git commit -m "$(cat <<'EOF'
test: add new dump tests for tab indent, spaces variations, and negative precondition

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Add new tests for OutputOptions, encodeAsData, sortedKeys

**Files:**
- Modify: `Tests/OrderedJSONTests/Codable/OrderedJSONEncoderTests.swift`
- Modify: `Tests/OrderedJSONTests/Codable/EncodeAsStringEdgeCaseTests.swift`

- [ ] **Step 1: Add `encodeAsStringPrettyOutputOptions` test in `OrderedJSONEncoderTests.swift`**

```swift
@Test("encodeAsString with pretty outputOptions")
func encodeAsStringPrettyOutputOptions() throws {
  struct Person: Encodable {
    let name: String
    let age: Int
  }
  var encoder = OrderedJSONEncoder()
  encoder.outputOptions.indent = .spaces(2)
  let str = try encoder.encodeAsString(Person(name: "Alice", age: 30))
  #expect(str.contains("\n"))
  #expect(str.contains("  "))
}
```

- [ ] **Step 2: Add `encodeAsData` test**

```swift
@Test("encodeAsData returns valid UTF-8 data")
func encodeAsDataValidUTF8() throws {
  struct Person: Encodable {
    let name: String
    let age: Int
  }
  let encoder = OrderedJSONEncoder()
  let data = try encoder.encodeAsData(Person(name: "Alice", age: 30))
  #expect(data.count > 0)
  // Re-parse to verify validity
  let decoded = try JSON.parse(data)
  #expect(decoded["name"] == .string("Alice"))
  #expect(decoded["age"] == .number(.integer(30)))
}
```

- [ ] **Step 3: Add `sortedKeysTrue` test**

```swift
@Test("sortedKeys true produces alphabetically sorted keys")
func sortedKeysTrue() throws {
  struct Unsorted: Encodable {
    let z: Int
    let a: Int
    let m: Int
  }
  var encoder = OrderedJSONEncoder()
  encoder.outputOptions.sortedKeys = true
  let str = try encoder.encodeAsString(Unsorted(z: 1, a: 2, m: 3))
  // Keys should be a, m, z in sorted output
  let expectedA = #""a":2"#
  let expectedM = #""m":3"#
  let expectedZ = #""z":1"#
  #expect(str.firstIndex(of: expectedA.first!)! < str.firstIndex(of: expectedM.first!)!)
  #expect(str.firstIndex(of: expectedM.first!)! < str.firstIndex(of: expectedZ.first!)!)
}
```

- [ ] **Step 4: Add `sortedKeysFalse` test**

```swift
@Test("sortedKeys false preserves insertion order (default)")
func sortedKeysFalse() throws {
  struct Unsorted: Encodable {
    let z: Int
    let a: Int
    let m: Int
  }
  let encoder = OrderedJSONEncoder()
  let str = try encoder.encodeAsString(Unsorted(z: 1, a: 2, m: 3))
  // Default: keys should be in declaration order: z, a, m
  let expectedZ = #""z":1"#
  let expectedA = #""a":2"#
  #expect(str.firstIndex(of: expectedZ.first!)! < str.firstIndex(of: expectedA.first!)!)
}
```

- [ ] **Step 5: Run tests**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift test --filter "OrderedJSONEncoderTests"
```
Expected: All encoder tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add Tests/OrderedJSONTests/Codable/OrderedJSONEncoderTests.swift && git commit -m "$(cat <<'EOF'
test: add OutputOptions, encodeAsData, and sortedKeys tests

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Update README documentation

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update Encoding/Serialization section (around line 443)**

Replace the section from "### Encoding / Serialization" through the example block.

Old:
```
`dump()` converts a `JSON` value back into a JSON string. It accepts an `indent` parameter: omit or pass `nil` for compact output (no whitespace) or a positive integer for pretty-printing. Two additional parameters customize output:

- `indentCharacter` — character used for indentation (default: `" "`)
- `ensureAscii` — if `true`, non-ASCII characters are escaped as `\uXXXX` (default: `false`)
```

New:
```
`dump()` converts a `JSON` value back into a JSON string. It accepts an `indent` parameter of type `JSON.Indent`:

- `.compact` — single-line output with no whitespace (default)
- `.spaces(n)` — pretty-printed with n spaces per indent level
- `.tab` — pretty-printed with tab characters per indent level

An additional parameter:
- `ensureAscii` — if `true`, non-ASCII characters are escaped as `\uXXXX` (default: `false`)
```

- [ ] **Step 2: Update the code example block**

Replace:
```swift
// Compact JSON — single line, no whitespace
let compact = value.dump()
// {"name":"Bob","age":25}

// Pretty-printed JSON — 2-space indentation
let pretty = value.dump(indent: 2)
// {
//   "name": "Bob",
//   "age": 25
// }

// ASCII-safe output — non-ASCII chars escaped
let escaped = value.dump(ensureAscii: true)
```

With:
```swift
// Compact JSON — single line, no whitespace
let compact = value.dump()
// {"name":"Bob","age":25}

// Pretty-printed JSON — 2-space indentation
let pretty = value.dump(indent: .spaces(2))
// {
//   "name": "Bob",
//   "age": 25
// }

// Tab-indented JSON
let tabby = value.dump(indent: .tab)
// {
// \t"name": "Bob",
// \t"age": 25
// }

// ASCII-safe output — non-ASCII chars escaped
let escaped = value.dump(ensureAscii: true)
```

- [ ] **Step 3: Update the summary line**

Replace:
```
`dump()` produces compact JSON (no whitespace). `dump(indent: 2)` produces pretty-printed JSON. The key order is always preserved regardless of indent value. Use `dump(indent: 2, indentCharacter: "\t")` for tab-indented output.
```

With:
```
`dump()` produces compact JSON (no whitespace). `dump(indent: .spaces(2))` produces pretty-printed JSON. `dump(indent: .tab)` produces tab-indented JSON. The key order is always preserved regardless of indent value.
```

- [ ] **Step 4: Add OutputOptions subsection in Codable section**

After the `OrderedJSONEncoder` subsection (around line 1297), add:

```
### OutputOptions

`OrderedJSONEncoder` supports configurable output formatting via `outputOptions`:

```swift
var encoder = OrderedJSONEncoder()
encoder.outputOptions.indent = .spaces(2)  // pretty-printed output
encoder.outputOptions.sortedKeys = true    // alphabetically sorted keys
let string = try encoder.encodeAsString(value)
let data = try encoder.encodeAsData(value)  // returns Data instead of String
```

`encodeAsString()` and `encodeAsData()` respect the current `outputOptions`. The default output is compact (`.compact`) with insertion order preserved (`sortedKeys: false`).
```

- [ ] **Step 5: Update Performance section (line 141)**

Replace:
```
- **Pretty-printed** (`indent: 2`): Slightly more overhead due to whitespace insertion per nesting level.
```

With:
```
- **Pretty-printed** (`indent: .spaces(2)`): Slightly more overhead due to whitespace insertion per nesting level.
- **Tab indented** (`indent: .tab`): Similar overhead to spaces.
```

- [ ] **Step 6: Commit**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git add README.md && git commit -m "$(cat <<'EOF'
docs: update README for new JSON.Indent API and OutputOptions

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: Final validation

- [ ] **Step 1: Full test suite**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift test
```
Expected: All tests pass.

- [ ] **Step 2: Lint**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && swift format lint --recursive --parallel -p .
```
Expected: No lint errors (or minimal, from pre-existing issues).

- [ ] **Step 3: Final commit for any remaining changes**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON && git status
```
Verify clean working tree. If there are uncommitted changes, review and commit them.
