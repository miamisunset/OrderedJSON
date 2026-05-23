# Progress

## Phase 1 — Core Types + Flatten (merged to `main`)

### What shipped
- `JSONNumber` enum: `.integer(Int64)` / `.float(Double)`, `Hashable`/`Sendable`/`Codable`
- `JSONValue` enum: `.object(OrderedJSONObject)`, `.array([JSONValue])`, `.string(String)`, `.number(JSONNumber)`, `.boolean(Bool)`, `.null`
- `OrderedJSONObject` typealias: `OrderedDictionary<String, JSONValue>`
- `flatten()` → `[(key: String, value: JSONValue)]` with dotted/indexed paths
- `Codable` encodes objects as alternating key-value pairs (order-preserving); decodes both keyed JSON objects and alternating pairs
- 18 tests covering all code paths

### Key decisions
- `OrderedDictionary` encodes as unkeyed alternating pairs (not JSON objects). Object encoding matches that format; decoding supports both keyed and unkeyed formats
- `JSONNumber` uses enum over `NSNumber` for `Sendable` safety
- Decoding heuristics: keyed container → object; unkeyed with even count + string keys → object (alternating pairs); else → array; single-value → scalar

## Phase 2 — Documentation with Verified Examples (merged to `main`)

### What shipped
- `README.md` covering installation, creating values, flatten, encoding/decoding, key order preservation, best practices
- `Tests/OrderedJSONTests/DocumentationExamplesTests.swift` — 9 tests exercising every README code example
- Fixed `swift format` commands in `AGENTS.md` (lint/format flags were incorrect)

### Key decisions
- README examples must compile and pass; test file mirrors them exactly
- Format commands: `swift format lint --recursive --parallel -p .` / `swift format format --recursive --parallel --in-place -p .`

## Phase 3 — Extra Fields Capture (`#[serde(flatten)]` equivalent) [in progress on `phase-3-extra-fields`]

### What's done
- `JSONValue.encodeStandard()` — encodes via `JSONSerialization` (keyed objects) for standard JSON compatibility
- `JSONValue.decode<T: Codable>(as:)` — decodes a single JSON value as any Codable type
- `splitExtraFields(from:knownKeys:)` — splits `OrderedJSONObject` into known/extra groups
- `UserWithExtra` test struct + 8 extra-fields tests covering: decode with known+extra, round-trip order preservation, empty extra, nested values, alternating-pairs encoding
- 6 `encodeStandard` tests, 4 `decode(as:)` tests, 6 `splitExtraFields` tests
- README section with example and helper documentation

### Key decisions
- Extra-fields pattern requires manual `Codable` implementation (no protocol/auto-magic approach due to recursion constraints)
- Uses a "base struct" for known fields + `encodeStandard()` to avoid recursion
- Encoding uses alternating pairs (unkeyed container) for order preservation
- `encodeStandard()` uses `JSONSerialization` with Objective-C bridging — preserves key order on modern Apple platforms
