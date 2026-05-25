# OrderedJSON Improvement Plan

This document identifies areas of improvement for the OrderedJSON library, organized into independent phases. Each phase focuses on one thing at a time, building on the previous.

## Current State

OrderedJSON covers ~95% of `nlohmann::basic_json`'s API surface. The flatten/unflatten implementation is now RFC 6901-compliant with proper input validation. All 400+ tests pass.

## Improvement Areas

Below are the gaps I've identified, ranked by impact. Each gets its own phase.

---

## Phase 1 — Missing value accessors

**Why**: nlohmann/json provides `get<int>()`, `get<double>()`, `get<bool>()`, `get<std::string>()`. We have `stringValue` but no `intValue`, `floatValue`, `boolValue`, or `numberValue` computed properties. These are the most obvious gap — users have to pattern-match or use throwing accessors for simple value extraction.

**Scope**:
- `intValue: Int64?` — returns the integer if `.integer`, or a clean integer if `.float`, else nil
- `floatValue: Double?` — returns the float if `.float`, or widened integer if `.integer`, else nil
- `boolValue: Bool?` — returns the boolean if `.boolean`, else nil
- `numberValue: JSONNumber?` — returns the underlying `JSONNumber` enum, nil for non-numbers
- Tests for each

**Files**: `JSON.swift` (add computed properties), `JSONCoreTests.swift` (add tests)

---

## Phase 2 — `contains(element: JSON)` for arrays

**Why**: nlohmann/json has `contains(key)` for objects and `contains(element)` for arrays using `std::find`. We only have `contains(_ key: String)` for objects. Adding array element containment fills a real gap — users can check if a value exists in an array without iterating manually.

**Scope**:
- `func contains(_ element: JSON) -> Bool` on `JSON` — checks if an element exists in an array
- Uses `==` for comparison
- For non-arrays, returns `false`
- Tests: existing array, missing element, non-array, empty array, nested

**Files**: `JSONLookup.swift` (add method), `JSONAccessTests.swift` or new test file (add tests)

---

## Phase 3 — `value(_ index: Int, default: JSON)` for arrays

**Why**: We have `value(_ key: String, default: JSON)` for objects but no array variant. nlohmann's `value()` works with indices too. Users currently must use `at(_ index:)` (throwing) or optional-binding. A default-value variant is the natural complement.

**Scope**:
- `func value(_ index: Int, default defaultValue: JSON) -> JSON` — returns the element at `index` if the array has that index, else `defaultValue`
- For non-arrays, returns `defaultValue`
- Tests: valid index, out of bounds, non-array

**Files**: `JSONAccess.swift` (add method), `JSONAccessTests.swift` (add tests)

---

## Phase 4 — Recursive merge in `update(with:mergeObjects:)`

**Why**: nlohmann/json's `update(other)` has a second parameter `merge_objects` (default `false`). When `true`, it recursively merges objects that share common keys instead of simply overwriting. Our `update(with:)` only does simple overwrite. This would be useful for merging configuration trees or nested defaults.

**Scope**:
- Add `mergeObjects: Bool = false` parameter to `update(with:)`
- When `mergeObjects` is true and both sides have an object at the same key, recurse into that key instead of replacing
- When `mergeObjects` is false (default), existing behavior unchanged
- Tests: simple merge, recursive merge with nested objects, mixed object/primitive

**Files**: `JSONClear.swift` (modify `update(with:)`), `JSONModifierTests.swift` (add tests)

---

## Phase 5 — Generic `get<T>()` accessor

**Why**: nlohmann has template `get<T>()` which maps JSON types to C++ types. We have throwing accessors (`requireString()`, `requireBool()`, etc.) but no generic dispatch. A `get<T>()` method would let users write `json.get(String.self)` instead of `try json.requireString()`, and could support more types.

**Scope**:
- `func get<T>(_: T.Type) throws -> T` where `T` is one of `String`, `Bool`, `Int64`, `Int`, `Double`, `Float`, `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64`, `Int8`, `Int16`, `Int32`
- Internally dispatches to existing `require*()` methods
- Tests for each type, type mismatch throws
- **Future**: `func get<T>(into: inout T) throws` (Swift-idiomatic `get_to()` equivalent)

**Files**: `JSONAccessors.swift` (add method), `JSONAccessTests.swift` (add tests)

---

## Phase 6 — Test coverage expansion

**Why**: While overall coverage is high, some edge cases in binary formats, patch, and SAX parsing may have untested paths. A coverage analysis run will identify specific gaps.

**Scope**:
- Run `swift test --enable-code-coverage` and analyze report
- Add tests for uncovered code paths
- Focus on binary format edge cases (truncated data, unknown markers)
- Focus on JSON Patch edge cases (complex nested operations)
- Focus on SAX parser edge cases (early termination, error recovery)

**Files**: Various test files

---

## Phase 7 — `numberValue` property for direct `JSONNumber` access

**(merged into Phase 1 — same scope)**

---

## Prioritization

| Phase | Effort | Impact | Risk |
|-------|--------|--------|------|
| 1 — Value accessors | Small | High | None (additive) |
| 2 — Array contains | Small | Medium | None (additive) |
| 3 — Array value default | Small | Medium | None (additive) |
| 4 — Recursive merge | Small | Medium | None (backward-compatible default) |
| 5 — Generic get<T> | Small | Medium | None (additive) |
| 6 — Test coverage | Medium | High (quality) | None |

## Execution

Each phase goes on a dedicated branch, follows the standard workflow (lint → format → test → PR → review → squash-merge), and updates `PROGRESS.md` on completion.
