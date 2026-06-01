---
name: PR #50 Code Review Fixes
description: Addresses 5 issues from PR #50 code review — force-unwrapped optionals, missing doc comment, duplicated serialization logic, dead code, and imprecise test assertion
metadata:
  type: project
  status: approved
---

## Scope

Fix all issues flagged in the PR #50 code review comment by @miamisunset.

### Changes

#### 1. Force-unwrapped `firstIndex(of:)` → `#require` (Medium)

**File:** `Tests/OrderedJSONTests/Codable/OrderedJSONEncoderTests.swift`

Replace force-unwrapped `firstIndex(of:)` calls with `try #require(...)` in three locations (lines 124-125, 138). Stops test-process crash if a character isn't found.

#### 2. Missing doc comment on `encodeAsString` (Low)

**File:** `Sources/OrderedJSON/Codable/OrderedJSONEncoder.swift:44`

Add `Parameter`, `Returns`, `Throws` documentation comment matching the style of `encodeAsData`.

#### 3. Duplicated serialization logic — merge sorted into main (Low)

**File:** `Sources/OrderedJSON/Parsing/JSONSerializer.swift`

- Add `sortedKeys: Bool = false` parameter to `serializeJSONCompact` and `serializeJSONPretty`
- When `sortedKeys` is true, sort `dict.keys` before iterating; otherwise use insertion order
- Delete all 4 sorted variants: `_sortedDump`, `_serializeSorted`, `_serializeSortedCompact`, `_serializeSortedPretty`
- Update `_sortedDump` call site in `OrderedJSONEncoder.encodeAsString` to use `dump(indent:sortedKeys:)` instead

#### 4. Dead code `guard let value = dict[key]` (Low)

**File:** `Sources/OrderedJSON/Parsing/JSONSerializer.swift`

Remove two `guard let value = dict[key] else { continue }` lines (currently at lines 257 and 308). These are unreachable since keys are derived from `dict.keys.sorted()`.

#### 5. Imprecise test assertion (Low)

**File:** `Tests/OrderedJSONTests/Codable/OrderedJSONEncoderTests.swift`

Replace `str.contains("\n")` / `str.contains("  ")` with exact string match of the expected formatted output for `encodeAsStringPrettyOutputOptions`.

### Dependencies

All changes are independent and can be made in any order. No test data changes needed.

### Verification

- `swift test` must pass (all existing and updated tests)
- `swift format lint --recursive --parallel -p .` must pass
