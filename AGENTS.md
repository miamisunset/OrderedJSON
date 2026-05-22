# OrderedJSON

Swift library that preserves JSON key order (deeply nested) with a `flatten` feature similar to `serde_json`.

## Commands

- `swift run` — build & run (no executable target currently; add one first)
- `swift test` — run all tests (uses Swift Testing, not XCTest)
- `swift build` — build library
- `swift format --mode lint --parallelism 1 -p .` — lint with SwiftFormat
- `swift format --mode format --parallelism 1 -p .` — auto-format with SwiftFormat

## Architecture

- Single target: `OrderedJSON` (library), single test target: `OrderedJSONTests`
- Uses `OrderedCollections` from `swift-collections` for ordered key preservation
- Minimal platforms: iOS 26 / macOS 26 / tvOS 26 / watchOS 26 (Swift 6.3, language mode v6)
- `StrictConcurrency` enabled — all public APIs must be `Sendable`-aware
- Source lives in `Sources/OrderedJSON/OrderedJSON.swift` (currently a stub)

## Key goals

1. **Ordered parsing** — `JSONObject` backed by `OrderedDictionary`; keys retain insertion order
2. **Deep order preservation** — nested objects and arrays all preserve order recursively
3. **Flatten** — `FlattenResult<Key, Value>` akin to `serde_json::Value::flatten()`, producing flat key–value pairs with dotted paths
4. **Codable** — `JSONValue` should be `Codable` (encodes/decode as standard JSON) while round-tripping preserves order

## Conventions

- Use `OrderedDictionary` (not `Dictionary`) for all JSON object representations
- Use `JSONValue` enum with cases: `.object(OrderedJSONObject)`, `.array([JSONValue])`, `.string(String)`, `.number(JSONNumber)`, `.boolean(Bool)`, `.null`
- `JSONNumber` stores `NSNumber` or a custom wrapper to preserve numeric type (int vs float) — no premature stringification
- `flatten()` returns `[(key: String, value: JSONValue)]` where keys are dot-separated paths (e.g. `"a.b.c"`)
- All tests use `@Test` / `#expect(...)` (Swift Testing, no XCTest)
- Prefer `package` access for testability over `public` on internal helpers

## Progress Tracking
- Never append raw phase logs to this file.
- Maintain a clean, up-to-date summary of active phases in this file.
- For completed phases: summarize key outcomes + decisions concisely in `PROGRESS.md`, then archive details if needed.
- Keep total length under ~800–1500 tokens when possible.

## Coverage
- Aim for 100% test coverage. Every new or changed code path must have a corresponding test.

## Workflow

- **Branch-first** — all development on a new branch; merge to `main` only after checks pass
- **Pre-merge** — run `swift test` (must pass) + `swift format --mode lint --parallelism 1 -p .` (must be clean) + `swift format --mode format --parallelism 1 -p .` (auto-format)
- **Order**: lint → format → test (format first so lint sees formatted code)

## Gotchas

- Swift 6 / language mode v6 means strict isolation; use `struct` / `Sendable` conformances rather than `actor` for value types
- `OrderedDictionary` is from `swift-collections`, import `OrderedCollections`
- No `main.swift` exists; add a CLI target if you need `swift run` to do something
