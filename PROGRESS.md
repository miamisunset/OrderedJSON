# Progress

## Phase 1 — Core Struct + Type Checks + Subscript + Capacity + Lookup + Modifiers + Flatten (complete)

### What shipped
- `JSON` struct wrapping `Storage` enum with 6 cases (object/array/string/number/boolean/null)
- `JSONNumber` enum: `.integer(Int64)` / `.float(Double)`, `Hashable`/`Sendable`
- Uses `OrderedDictionary<String, JSON>` directly (no typealias)
- Factory methods: `JSON.object(...)`, `JSON.array(...)`, `JSON.string(...)`, `JSON.number(...)`, `JSON.boolean(...)`, `JSON.null`, `JSON.nullValue()`
- Type checks: `isNull`, `isBoolean`, `isNumber`, `isInteger`, `isFloat`, `isString`, `isObject`, `isArray`, `isPrimitive`, `isStructured`, `type`, `typeName`
- Subscript: `[key:]`, `[index:]` (get/set), `at(_:)`, `value(_:default:)`
- Capacity: `count`, `isEmpty`, `maxCount`, `first`, `last`
- Lookup: `contains(_:)`, `count(_:)`, `find(_:)`
- Modifiers: `clear()`, `erase(_:)`, `append(_:)`, `insert(_:at:)`, `emplace(_:)`, `emplace(key:default:)`, `update(with:)`, `swap(&:)`
- `flatten()` → JSON object with JSON Pointer keys (`/a/b/c`)
- `unflatten()` → reconstructs nested structure
- `dump(indent:, indentChar:, ensureAscii:)` → pretty-printing
- `JSONPointer` struct with `resolve(_:)`
- `parse()` → order-preserving recursive descent parser
- `dump()` → standard JSON serialization (compact or pretty-printed)

- 41 tests covering all code paths + documentation examples

### Key decisions
- Factory methods use `static func` on `JSON` struct (not enum case patterns)
- `null` is a static property (`JSON.null`), with `nullValue()` as alternative
- `flatten()` for empty objects/arrays returns empty JSON object (no leaf entry)
- `dump(-1)` produces compact output
- `dump(indent: >0)` produces pretty-printed output with indentation

## Phase 2 — Comparison Operators + Sequence Conformance (complete)

### What shipped
- Comparison operators: `<`, `>`, `<=`, `>=` (matching nlohmann/json semantics)
- `Sequence` conformance with `JSONIterator` — iterates array elements, object values, or single scalar
- `items()` — returns key-value pairs for objects
- 20 new tests covering comparisons and sequence behavior

### Key decisions
- Boolean `<` uses `a == false && b == true` (Swift Bool doesn't support `<`)
- Object/array comparison uses count (matching nlohmann/json)
- `Sequence` over objects yields values (not key-value pairs); use `items()` for pairs

## Phase 3 — JSON Patch + Merge Patch (complete)

### What shipped
- `patch(_:)` — applies a JSON Patch (RFC 6902), returns new JSON value (non-mutating)
- `patchInPlace(_:)` — applies a JSON Patch in-place (mutating)
- `diff(_:_:)` — computes JSON Patch between source and target
- `mergePatch(_:)` — applies a JSON Merge Patch (RFC 7396)
- Operations: add, remove, replace, copy, move, test
- Recursive tree rebuilding for path-based mutations
- Array `-` syntax (append), insert/replace semantics per RFC
- `stringValue` computed property on `JSON`
- `invalidPatch(String)` error case on `JSONError`
- 30 new tests covering all patch operations, diff, merge patch edge cases

### Key decisions
- Patch operations use recursive tree rebuilding (traverseAndSet/traverseAndRemove) rather than complex parent mutation with `inout` references — cleaner and avoids ownership issues
- `-` array append marker handled as a special segment in traversal
- `isAdd` flag differentiates insert-vs-replace semantics for array targets
- Merge Patch uses recursive merge: null removes keys, object patches recurse into existing objects, non-object patches replace values

## Phase 4 — SAX Parsing (complete)

### What shipped
- `JSONSAXEventHandler` protocol with callbacks for null, boolean, integer, float, string, startObject, key, endObject, startArray, endArray, parseError
- `saxParse(_:handler:)` — SAX-style parse that calls handler callbacks instead of constructing JSON tree
- `accept(_:)` — non-throwing validation that returns `true` for valid JSON without constructing tree
- 24 tests covering all event types, error conditions, accept valid/invalid

### Key decisions
- Protocol uses `package` visibility (not `public`) because `JSONParseError` is `package`
- `saxParse` duplicates `skipWhitespace`/`parseString` locally instead of promoting private helpers — avoids changing existing parser code
- Handler methods return `Bool` — returning `false` stops parsing early (no error emitted)
- `accept()` mirrors `saxParse` structure but discards values and never calls key/string/float callbacks

## Phase 6 — Comprehensive User Documentation (complete)

### What shipped
- Fully rewritten `README.md` with explanatory prose alongside every code example
- "Why OrderedJSON?" section explaining the rationale for key-order preservation
- Narrative sections for each API area: creating values, parsing, encoding, type checks, subscript/at/value, modifiers, flatten, comparison, sequence, patch/merge/diff, SAX, binary formats
- Best practices section with concrete guidance
- Removed all references to removed APIs (`encodeStandard`, `splitExtraFields`, stale visibility warning)
- All code examples match current `JSON` struct API (not old `JSONValue`)

### Key decisions
- Documentation is organized by feature area, matching nlohmann/json documentation structure
- Every section includes both "what it does" and "when to use it" explanations
- Code examples are kept concise but are preceded by prose explaining the concept
- Binary formats include a comparison table showing which format is best for which use case

## Phase 5 — Binary Formats (complete)

### What shipped
- CBOR: `fromCBOR(_:)`, `toCBOR()` — RFC 7049 binary format
- MessagePack: `fromMsgPack(_:)`, `toMsgPack()` — MessagePack binary format
- UBJSON: `fromUBJSON(_:)`, `toUBJSON()` — Universal Binary JSON
- BSON: `fromBSON(_:)`, `toBSON()` — BSON binary format
- BJData: `fromBJData(_:)`, `toBJData()` — BJData binary format
- All five formats implement encode/decode with correct marker handling, integer/float type selection, string/array/object encoding
- 60 tests across all binary formats covering round-trip, edge cases (NaN, Infinity, empty containers), negative integers, and error handling

### Key decisions
- Binary format methods are `package` (not `public`) — same visibility as core API
- CBOR float decode uses already-consumed `argument` rather than re-reading payload bytes (fixes out-of-bounds crash)
- BSON document length `endPos` includes 4 length bytes + 1 null terminator (`pos + docLen - 5`)
- MessagePack/UBJSON/BJData encode uses `UInt8(bitPattern:)` for negative Int8 values to avoid Swift runtime trap
- BJData string length decoder handles both `UInt8` and `Int8` markers since encoder uses unsigned for small lengths
- All round-trips verified: encode → decode produces identical value

## Phase 7 — Test Coverage Improvement (complete)

### What shipped
All 302 tests pass with zero failures. Fixed the following bugs:

- **JSONSerializer.swift**: `dump(ensureAscii: true)` now correctly escapes non-ASCII characters in compact mode by propagating `ensureAscii` through `serializeJSONCompact` and `serializeJSONString`.
- **JSONParser.swift**: Fixed `parseUnicodeEscape` double-increment bug — escape handling in `parseString` was doing `pos += 1` unconditionally after the switch, but `parseUnicodeEscape` already advanced past the hex digits. Moved `pos += 1` into each individual case to avoid the extra increment.
- **JSONParser.swift**: `parseNumber` now rejects incomplete floats like `"0."` (no digit after decimal point) with `unexpectedEnd()` instead of accepting them via `Double("0.")` → `0.0`.
- **JSONFlatten.swift**: `setJSONPointerPath` was missing the non-leaf object path branch — only handled `rest.isEmpty` (leaf) but not `rest` having further segments. Added the missing `else` branch that creates/recurses into intermediate objects.
- **JSONFlatten.swift**: `setJSONPointerPath` leaf creation for non-object roots was creating an unnecessary intermediate `JSON.object()` then overwriting it. Simplified to set the value directly.
- **JSONFlatten.swift**: `unflatten()` now handles keys without a leading `/` by checking whether the first split segment is empty before applying `dropFirst()`.

### Key decisions
- `parseUnicodeEscape` advances `pos` by 5 total (1 for 'u' + 4 for hex digits); the caller must not add an extra increment.
- `unflatten()` supports both `/a/b/c` and `a/b/c` key formats by conditionally dropping the leading empty segment.
