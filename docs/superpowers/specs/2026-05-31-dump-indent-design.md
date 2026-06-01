# Dump Indent API Redesign

**Date:** 2026-05-31
**Status:** Approved design

## Summary

Replace the freeform `dump(indent: Int?, indentCharacter: Character, ensureAscii: Bool)` API with a type-safe `JSON.Indent` enum that only allows valid JSON indent values (none, spaces, tab). Add Foundation-style `OutputOptions` to `OrderedJSONEncoder` for pretty-printing and sorted keys. Update all call sites, tests, and documentation.

## Scope

- Source changes: `JSONSerializer.swift`, `JSON+ObjectBuilder.swift`, `JSON+ArrayBuilder.swift`, `OrderedJSONEncoder.swift`
- New types: `JSON.Indent` enum, `OrderedJSONEncoder.OutputOptions` struct
- Test changes: `JSONCoreTests.swift`, `READMEEncodingTests.swift`, `EncodeAsStringEdgeCaseTests.swift`, `JSONIntegrationParseDumpTests.swift`, builder tests
- Documentation: `README.md` Encoding/Serialization section, Codable section

## API Design

### JSON.Indent enum

Following Swift API Design Guidelines (lowerCamelCase cases, nested enum in `JSON`):

```swift
extension JSON {
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
}
```

The `dump()` implementation validates `.spaces` width at the point of use:

```swift
case .spaces(let width):
  precondition(width >= 0, "Indent.spaces width must be non-negative")
  // ... use width for padding
```

### dump() — full replacement

Old signature (removed):
```swift
public func dump(indent: Int? = nil, indentCharacter: Character = " ", ensureAscii: Bool = false) -> String
```

New signature:
```swift
public func dump(indent: Indent = .compact, ensureAscii: Bool = false) -> String
```

Internal behavior:
- `.compact` → existing compact serialization (no whitespace)
- `.spaces(n)` → existing pretty-print logic, using `n` spaces per level
- `.tab` → existing pretty-print logic, using `\t` per level

### Builder buildString

Both `ObjectBuilder.buildString(indent: Int?)` and `ArrayBuilder.buildString(indent: Int?)` change to:

```swift
public func buildString(indent: Indent = .compact) -> String {
  return build().dump(indent: indent)
}
```

### OrderedJSONEncoder.OutputOptions

```swift
extension OrderedJSONEncoder {
  /// Options controlling JSON output formatting.
  public struct OutputOptions: Hashable, Sendable {
    /// Indentation style for pretty-printed output. Defaults to `.compact`.
    public var indent: JSON.Indent = .compact
    /// If true, object keys are sorted alphabetically during serialization.
    public var sortedKeys: Bool = false
    
    public init(indent: JSON.Indent = .compact, sortedKeys: Bool = false) {
      self.indent = indent
      self.sortedKeys = sortedKeys
    }
  }
}
```

Added to `OrderedJSONEncoder`:

```swift
/// Output formatting options.
public var outputOptions: OutputOptions = .init()

/// Encodes a value and returns the JSON string, using current output options.
public func encodeAsString<T: Encodable>(_ value: T) throws -> String {
  let json = try encode(value)
  if outputOptions.sortedKeys {
    return json.sortedDump(indent: outputOptions.indent)
  }
  return json.dump(indent: outputOptions.indent)
}

/// Encodes a value and returns the JSON data, using current output options.
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

Sorted dump is implemented as a private helper that sorts `OrderedDictionary` keys before serializing via the existing compact/pretty path.

### Sorted dump implementation

Sorted dump sorts keys *during serialization* rather than modifying the original `JSON` tree, preserving the value's insertion order for subsequent operations.

```swift
private func sortedDump(indent: Indent = .compact, ensureAscii: Bool = false) -> String {
  var string = ""
  serializeSorted(self, indent: indent, depth: 0, ensureAscii: ensureAscii, into: &string)
  return string
}

private func serializeSorted(
  _ value: JSON, indent: Indent, depth: Int, ensureAscii: Bool,
  into string: inout String
) {
  // Same as serializeJSONCompact/serializeJSONPretty but for objects,
  // sort keys alphabetically before iterating.
  // For non-object values, delegate to the standard serialize methods.
}
```

## Test Plan

Following Swift Testing conventions (struct suites, `#expect`, `#require`):

### JSONCoreTests updates
- Update `dumpCompact` → use `.compact` instead of `indent: nil`
- Update `dumpPretty` → use `.spaces(2)` instead of `indent: 2`
- Update `dumpPrettyEmpty`, `dumpPrettyNull`, `dumpPrettyBool`, `dumpPrettyNumber`, `dumpPrettyString` → use `.spaces(2)`
- Update `dumpEnsureAscii` → use `.compact` instead of `indent: nil`
- Update `dumpEscapedCharacters`, `dumpBackspaceFormfeed`, `dumpControlCharacters` → use `.compact`

### New dump tests
- `dumpTabIndent` — verify `.tab` produces `\t` indentation
- `dumpSpaces4` — verify `.spaces(4)` produces 4-space indentation
- `dumpSpaces0` — verify `.spaces(0)` produces no leading whitespace (valid edge case)
- `dumpSpacesNegative` — verify `.spaces(-1)` triggers precondition failure
- `dumpCompact` — verify `.compact` produces no whitespace (already exists, update)
- `dumpDefaultCompact` — verify `dump()` with no argument matches `.compact`

### Builder tests (existing)
- Update `buildString` tests to use new `Indent` parameter

### Encoder tests
- `encodeAsStringDefaultOptions` — verify default output matches `.compact`
- `encodeAsStringPrettyOptions` — verify `outputOptions.indent = .spaces(2)` produces pretty output
- `encodeAsData` — verify returns valid UTF-8 data
- `encodeAsDataRoundTrip` — encode then decode, verify equality
- `sortedKeysTrue` — verify keys are alphabetically sorted
- `sortedKeysFalse` — verify insertion order preserved (default)

### Integration tests
- Update `parseDumpParseObject` → uses `dump()` default (`.compact`)
- Update `parseDumpPrettyRoundTrip` → uses `.spaces(2)` instead of `indent: 2`
- Update `parseDumpEnsureAsciiRoundTrip` → uses `.compact` for the compact dump calls

## Documentation updates

### README Encoding/Serialization section
Replace old examples:
```
// Old:
let compact = value.dump()                          // {"name":"Bob","age":25}
let pretty = value.dump(indent: 2)                  // pretty with 2-space indent
let escaped = value.dump(ensureAscii: true)
// "Use dump(indent: 2, indentCharacter: \"\\t\") for tab-indented output"

// New:
let compact = value.dump()                          // {"name":"Bob","age":25}
let pretty = value.dump(indent: .spaces(2))         // pretty with 2-space indent
let tabby = value.dump(indent: .tab)                // tab-indented
let escaped = value.dump(ensureAscii: true)
```

### README Codable section
Add subsection for `OutputOptions` and `encodeAsData`.

### API doc comments
Update `dump()`, `buildString()`, `OrderedJSONEncoder` doc comments.

## Implementation order

1. Add `JSON.Indent` enum
2. Update `dump()` implementation (internal serialize methods unchanged, just new public signature)
3. Update `buildString` in both builders
4. Update `encodeAsString` to use new API
5. Add `OutputOptions` and `encodeAsData`
6. Add sorted dump helper
7. Update all existing tests
8. Add new tests
9. Update README
10. Run full test suite + lint

## Risk analysis

- **Backward compatibility**: Breaking change. Old `dump(indent: 2, indentCharacter: "\t")` no longer compiles. Mitigated by clear documentation and migration guide in README.
- **Sorted keys performance**: Sorting adds O(n log n) per object. Only affects when `sortedKeys: true`.
- **encodeAsData error handling**: UTF-8 encoding failure is extremely unlikely (JSON strings are already valid Unicode). We throw a descriptive error just in case.
