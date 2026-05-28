# OrderedJSON — Swift translation of nlohmann/json

Swift library that preserves JSON key order with a rich method-based API mirroring `nlohmann::basic_json` (`JSON for Modern C++`). Includes flatten/unflatten, JSON Patch/Merge Patch, SAX parsing, binary format support, and full subscript/type-check/modifier access.

## Commands

- `swift run` — build & run (no executable target currently; add one first)
- `swift test --enable-code-coverage` — run all tests with code coverage (uses Swift Testing, not XCTest)
- `swift build` — build library
- `swift format lint --recursive --parallel -p .` — lint with SwiftFormat
- `swift format format --recursive --parallel --in-place -p .` — auto-format with SwiftFormat

## Architecture

- Single target: `OrderedJSON` (library), single test target: `OrderedJSONTests`
- Uses `OrderedCollections` from `swift-collections` for ordered key preservation
- Minimal platforms: iOS 26 / macOS 26 / tvOS 26 / watchOS 26 (Swift 6.3, language mode v6)
- `StrictConcurrency` enabled — all public APIs must be `Sendable`-aware
- Core type: `JSON` struct wrapping a `Storage` enum (6 cases: object/array/string/number/boolean/null)
- Source organized by concern in `Sources/OrderedJSON/{Core,Parsing,Access,Modifiers,Flatten,Patch,SAX,Binary,Operators,Builder,Codable}/`
- Tests mirror the same structure in `Tests/OrderedJSONTests/`

## Key goals

1. **Ordered parsing** — `JSON` backed by `OrderedDictionary`; keys retain insertion order
2. **Rich API** — mirror nlohmann/json: subscript, type checks, modifiers, capacity, lookup, comparison, sequence, flatten/unflatten, patch/diff/merge, SAX parsing, binary formats
3. **Flatten** — `flatten()` produces JSON Pointer keys (`/a/b/c`), `unflatten()` reconstructs
4. **Binary formats** — CBOR, MessagePack, UBJSON, BSON, BJData support
5. **Codable support** — `JSON` conforms to `Encodable`/`Decodable` for Foundation interop; `OrderedJSONEncoder`/`OrderedJSONDecoder` preserve key order; `JSONWithExtras<T>` captures unknown keys

## Key goals (Codable)

6. **OrderedJSONEncoder** — encodes `Codable` types into `JSON` with key declaration order preserved
7. **OrderedJSONDecoder** — decodes `JSON`/`Data`/`String` into `Codable` types, preserving key order
8. **JSONWithExtras<T>** — serde-flatten style wrapper capturing unknown keys
9. **Full Codable surface** — all integer/unsigned widths, `decodeIfPresent`, `superEncoder`/`superDecoder`, coding path propagation

## Conventions

- Use `OrderedDictionary` (not `Dictionary`) for all JSON object representations
- Core type is `JSON` struct (not `JSONValue` enum); enum stays as internal `Storage`
- `JSONNumber` enum: `.integer(Int64)` / `.float(Double)` — no premature stringification
- `flatten()` returns `JSON` object with JSON Pointer keys (`/` prefix)
- All tests use `@Test` / `#expect(...)` (Swift Testing, no XCTest)
- Prefer `package` access for testability over `public` on internal helpers

## Plan Reference
- Track active phases in `API_PLAN.md`.
- For completed phases: summarize key outcomes + decisions in `API_PLAN.md`, then archive details if needed.
- Use the `swift-api-design-guidelines-skill` when designing or reviewing public, private and internal APIs.
- Keep `AGENTS.md` length under ~800–1500 tokens when possible.

## Coverage
- Aim for 100% test coverage. Every new or changed code path must have a corresponding test.

## Workflow

> **Hard Rule**: Every change goes on a dedicated feature branch — never commit or push directly to `main`. Open a PR for every branch and wait for human review before merging.

- **Branch required** — every change, including documentation-only updates, starts on a new branch off `main`
- **PR required** — open a pull request for every branch; never push to `main` directly
- **Do not self-merge** — never use `gh pr merge --admin` or any flag that bypasses review; wait for a human to approve
- **Pre-merge** — run `swift test --enable-code-coverage` (must pass) + `swift format lint --recursive --parallel -p .` (must be clean) + `swift format format --recursive --parallel --in-place -p .` (auto-format)
- **Order**: lint → format → test (format first so lint sees formatted code)
- **Merge method**: squash and merge only — keeps a clean linear history with one commit per PR

## Gotchas

- Swift 6 / language mode v6 means strict isolation; use `struct` / `Sendable` conformances rather than `actor` for value types
- `OrderedDictionary` is from `swift-collections`, import `OrderedCollections`
- No `main.swift` exists; add a CLI target if you need `swift run` to do something
- Multi-file project: `Package.swift` must list all source files explicitly or use a directory-based source layout
