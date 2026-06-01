# PR #51 Review Fixes — Design Spec

## Overview

Address four review findings from PR #51's code review comment, completing the type-hierarchy alignment with nlohmann/json.

## Findings and Fixes

### Finding 1: Stale comment in READMEComparisonTests.swift (lines 13-14)

**Problem:** Comment says cross-type `<` returns `false`, which is now incorrect after the PR changed cross-type comparisons to use the type hierarchy.

**Fix:** Update lines 13-14 to describe the new cross-type type-hierarchy behavior. Simple doc update.

### Finding 2: Array comparison by count only (JSON+Comparison.swift:55)

**Current behavior:** `case (.array(let a), .array(let b)): return a.count < b.count` — compares arrays solely by element count.

**nlohmann/json behavior:** Element-by-element lexicographic comparison (like tuple comparison). First non-equal pair determines result; if all prefix elements equal, shorter array is less.

**Fix:** Replace count-only comparison with lexicographic iteration:

```swift
case (.array(let a), .array(let b)):
    for (lhs, rhs) in zip(a, b) {
        if lhs < rhs { return true }
        if rhs < lhs { return false }
    }
    return a.count < b.count
```

**Edge cases covered:**
- Equal arrays → `false` (no element differs, counts equal)
- Same prefix, different length → shorter is less
- Same prefix, same length → first differing element decides
- Empty arrays → `false` (both zero-length, no iteration)

### Finding 3: Object comparison by count only (JSON+Comparison.swift:56)

**Current behavior:** `case (.object(let a), .object(let b)): return a.count < b.count` — compares objects solely by key count.

**nlohmann/json behavior:** Compares objects by iterating sorted key-value pairs. `std::map` provides sorted iteration; our `OrderedDictionary` preserves insertion order, so keys must be sorted explicitly.

**Fix:** Replace count-only comparison with sorted key-value pair iteration:

```swift
case (.object(let a), .object(let b)):
    let aSorted = a.elements.sorted { $0.key < $1.key }
    let bSorted = b.elements.sorted { $0.key < $1.key }
    for (lhs, rhs) in zip(aSorted, bSorted) {
        if lhs.key < rhs.key { return true }
        if rhs.key < lhs.key { return false }
        if lhs.value < rhs.value { return true }
        if rhs.value < lhs.value { return false }
    }
    return a.count < b.count
```

**Edge cases covered:**
- Equal objects → `false` (same sorted key-value pairs)
- Same keys, different values → first differing value decides
- Different keys → first differing key (in sorted order) decides
- One object is superset of another → count comparison decides
- Empty objects → `false`

### Finding 4: `binary` in doc comments (JSON+Comparison.swift:7, 15)

**Problem:** Doc comments mention `binary(6)` in the type hierarchy, but `Storage` has no `binary` case and `typeOrder` has no `binary` arm.

**Fix:** Remove `binary` from the hierarchy comments in `JSON+Comparison.swift`. The exhaustive `typeOrder` switch already ensures compile-time detection if `binary` is ever added to `Storage`.

### Doc comment updates (JSON+Comparison.swift)

Update the `operator<` doc comment to reflect:
- Element-wise array comparison
- Sorted key-value object comparison
- Remove `binary` references

## Test Plan

### New tests in JSONComparisonEdgeCaseTests.swift

1. **Array element-wise: same prefix, different length** — e.g., `[1, 2] < [1, 2, 3]` is `true`
2. **Array element-wise: same prefix, same length** — e.g., `[1, 2] < [1, 3]` is `true`, `[1, 3] < [1, 2]` is `false`
3. **Array element-wise: mixed types** — e.g., `[1, "a"] < [1, "b"]` uses type hierarchy for the second element
4. **Object key-wise: different keys** — e.g., `{"a": 1} < {"b": 2}` compares keys `"a" < "b"`
5. **Object key-wise: same keys, different values** — e.g., `{"a": 1} < {"a": 2}` compares values
6. **Object key-wise: superset keys** — e.g., `{"a": 1} < {"a": 1, "b": 2}` uses count comparison

### READMEComparisonTests.swift updates

- Update stale comment on lines 13-14
- No test logic changes needed (existing cross-type tests already pass with type hierarchy)

## Scope

- Files modified: `JSON+Comparison.swift`, `READMEComparisonTests.swift`, `JSONComparisonEdgeCaseTests.swift`
- No new types or public API changes
- No breaking changes to existing comparison behavior for same-type values
