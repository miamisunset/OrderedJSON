# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- `swift build` — build the OrderedJSON library
- `swift test` — run all tests (uses Swift Testing, not XCTest)
- `swift test --enable-code-coverage` — run tests with code coverage
- `swift test --filter "TestName"` — run a specific test
- `swift format lint --recursive --parallel -p .` — lint with SwiftFormat
- `swift format format --recursive --parallel --in-place -p .` — auto-format
- Pre-push workflow: lint → format → test (run in that order)
- Smoke test driver at `.claude/skills/run-orderedjson/driver.swift` — exercises key APIs via a temporary SwiftPM package (see skill for commands)

## Architecture

- **Single library target**: `OrderedJSON` in `Sources/OrderedJSON/`, with source files organized by concern:
  - `Core/` — `JSON` struct wrapping `Storage` enum (object/array/string/number/boolean/null), `JSONNumber`, `JSONError`, typed accessors
  - `Parsing/` — recursive descent parser (`JSONParser`, `ParseCursor`, `JSONSerializer`)
  - `Access/` — subscript, `at()`, `value()`, lookup/capacity methods
  - `Modifiers/` — clear, remove, append, insert, setDefault, update, swap
  - `Operators/` — comparison operators, `Sequence` conformance
  - `Flatten/` — `flatten()`/`unflatten()`, `JSONPointer`
  - `Patch/` — JSON Patch (RFC 6902), diff, JSON Merge Patch (RFC 7396)
  - `SAX/` — streaming SAX parsing with `JSONSAXEventHandler`
  - `Binary/` — CBOR, MessagePack, UBJSON, BSON, BJData encode/decode
  - `Builder/` — `JSON.ObjectBuilder` and `JSON.ArrayBuilder`
  - `Codable/` — `OrderedJSONEncoder`, `OrderedJSONDecoder`, `JSONWithUnknownKeys`, convenience `JSON.encode`/`decode`
  - `Schema/` — JSON Schema compilation, validation, format validation, inference
- **Test target**: `OrderedJSONTests` in `Tests/OrderedJSONTests/`, mirroring source structure
- **External dependency**: `swift-collections` (`OrderedDictionary`) for ordered key preservation
- **Platforms**: iOS 26 / macOS 26 / tvOS 26 / watchOS 26 (Swift 6.3, language mode v6)
- **Concurrency**: `StrictConcurrency` enabled; `JSON` is `Hashable` + `Sendable` value type

## Key Design Decisions

- `JSON` is a `struct` wrapping internal `Storage` enum — not a protocol hierarchy
- `JSONNumber` is `.integer(Int64)` / `.float(Double)` — preserves integer-vs-float distinction through round-trips
- All JSON objects use `OrderedDictionary`, never plain `Dictionary`
- All tests use Swift Testing (`@Test`, `#expect(...)`) — no XCTest
- `@dynamicMemberLookup` for dot-notation key access; missing keys return `.null`
- No `ExpressibleBy*Literal` conformances (intentional — type safety concerns)
- Prefer `package` access for testability over `public` on internal helpers

## Schema Tests

- Schema test suite uses a git submodule at `Tests/JSON-Schema-Test-Suite/`
- Test resource file: `Tests/OrderedJSONTests/Schema/JSONSchemaTestSuite/metaschemas.json`
- `JSONSchemaTestSuiteRunner.swift` runs the official JSON Schema Test Suite

## Key Goals (from AGENTS.md)

1. Ordered parsing — `OrderedDictionary`-backed `JSON`, keys retain insertion order
2. Rich API mirroring nlohmann/json: subscript, type checks, modifiers, capacity, lookup, comparison, sequence, flatten/unflatten, patch/diff/merge, SAX parsing, binary formats
3. Codable support — `JSON` conforms to `Encodable`/`Decodable`; `OrderedJSONEncoder`/`OrderedJSONDecoder` preserve key order; `JSONWithUnknownKeys<T>` captures unknown keys
4. Full binary format support — CBOR, MessagePack, UBJSON, BSON, BJData
5. Aim for 100% test coverage — every new or changed code path must have a corresponding test
