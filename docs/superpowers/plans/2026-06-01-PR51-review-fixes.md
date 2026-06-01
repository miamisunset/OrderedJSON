# PR #51 Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address four review findings from PR #51's code review: stale comment, element-wise array comparison, sorted key-value object comparison, and binary doc cleanup.

**Architecture:** The PR already added `typeOrder` helper and cross-type comparison. These fixes complete the nlohmann/json semantic alignment by fixing array/object comparison logic and cleaning up docs.

**Tech Stack:** Swift 6.3, swift-collections (OrderedDictionary)

---

## File Structure

| File | Responsibility | Change |
|------|---------------|--------|
| `Sources/OrderedJSON/Operators/JSON+Comparison.swift` | Comparison operators | Fix array/object comparison, clean binary from docs |
| `Tests/OrderedJSONTests/READMEComparisonTests.swift` | README example tests | Update stale comment |
| `Tests/OrderedJSONTests/Operators/JSONComparisonEdgeCaseTests.swift` | Edge case tests | Add array/object element-wise tests |

---

### Task 1: Fix stale comment in READMEComparisonTests.swift

**Files:**
- Modify: `Tests/OrderedJSONTests/READMEComparisonTests.swift:13-14`

- [ ] **Step 1: Update the stale comment**

Replace lines 13-14:
```swift
  // Note: Cross-type < returns false per current implementation.
  // Only same-type comparisons are supported.
```
with:
```swift
  // Cross-type < uses the nlohmann/json type hierarchy:
  // null < boolean < number < object < array < string
```

The updated file should look like:
```swift
  @Test func readmeTypeOrdering() {
    // Cross-type < uses the nlohmann/json type hierarchy:
    // null < boolean < number < object < array < string
    #expect(JSON.null < JSON.boolean(true))
    ...
```

- [ ] **Step 2: Commit**

```bash
git add Tests/OrderedJSONTests/READMEComparisonTests.swift
git commit -m "docs: fix stale comment in READMEComparisonTests cross-type docs"
```

---

### Task 2: Fix array comparison — element-by-element lexicographic

**Files:**
- Modify: `Sources/OrderedJSON/Operators/JSON+Comparison.swift:55`
- Test: existing cross-type and comparison tests should still pass

- [ ] **Step 1: Replace count-only array comparison with element-wise**

In `JSON+Comparison.swift`, replace line 55:
```swift
    case (.array(let a), .array(let b)): return a.count < b.count
```
with:
```swift
    case (.array(let a), .array(let b)):
      for (lhs, rhs) in zip(a, b) {
        if lhs < rhs { return true }
        if rhs < lhs { return false }
      }
      return a.count < b.count
```

- [ ] **Step 2: Update the doc comment for `operator<`**

Update line 36 from:
```swift
  /// - Arrays and objects are compared by count (shorter is smaller).
```
to:
```swift
  /// - Arrays are compared element-by-element (shorter is smaller if all equal).
  /// - Objects are compared by count (shorter is smaller).
```

(Objects will be fixed in Task 3 — this is an intermediate state)

- [ ] **Step 3: Run tests to verify no regressions**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON/.claude/worktrees/type-hierarchy-fix
swift test 2>&1
```

Expected: All tests pass. No regressions in same-type comparisons, NaN behavior, or cross-type hierarchy.

- [ ] **Step 4: Commit**

```bash
git add Sources/OrderedJSON/Operators/JSON+Comparison.swift
git commit -m "fix: implement element-wise array comparison matching nlohmann/json"
```

---

### Task 3: Fix object comparison — sorted key-value pairs

**Files:**
- Modify: `Sources/OrderedJSON/Operators/JSON+Comparison.swift:56`

- [ ] **Step 1: Replace count-only object comparison with sorted key-value iteration**

In `JSON+Comparison.swift`, replace line 56:
```swift
    case (.object(let a), .object(let b)): return a.count < b.count
```
with:
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

- [ ] **Step 2: Update the doc comment**

Update the doc comment (same line 36 area) to:
```swift
  /// - Arrays are compared element-by-element (shorter is smaller if all equal).
  /// - Objects are compared by sorted key-value pairs (shorter is smaller if all equal).
```

- [ ] **Step 3: Run tests**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON/.claude/worktrees/type-hierarchy-fix
swift test 2>&1
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add Sources/OrderedJSON/Operators/JSON+Comparison.swift
git commit -m "fix: implement sorted key-value object comparison matching nlohmann/json"
```

---

### Task 4: Clean up `binary` references in doc comments

**Files:**
- Modify: `Sources/OrderedJSON/Operators/JSON+Comparison.swift:7,15`

- [ ] **Step 1: Remove binary from the top-level comment (line 7)**

Replace:
```swift
// null < boolean < number < object < array < string < binary
```
with:
```swift
// null < boolean < number < object < array < string
```

- [ ] **Step 2: Remove binary from the typeOrder doc comment (line 15)**

Replace:
```swift
/// null(0) < boolean(1) < number(2) < object(3) < array(4) < string(5) < binary(6)
```
with:
```swift
/// null(0) < boolean(1) < number(2) < object(3) < array(4) < string(5)
```

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Operators/JSON+Comparison.swift
git commit -m "docs: remove binary references from type hierarchy comments"
```

---

### Task 5: Add edge case tests for element-wise array and key-value object comparison

**Files:**
- Modify: `Tests/OrderedJSONTests/Operators/JSONComparisonEdgeCaseTests.swift`

- [ ] **Step 1: Add array element-wise edge case tests**

Add a new suite section in `JSONComparisonEdgeCaseTests.swift` after the `crossTypeAllPairs` test (after line 233):

```swift
  // MARK: - Array element-wise comparison

  @Test("array element-wise — same prefix, different length")
  func arrayElementWiseDifferentLength() {
    let short = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
    let long = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2)), JSON.number(.integer(3))])

    #expect(short < long)
    #expect(!(long < short))
    #expect(long > short)
    #expect(!(short > long))
  }

  @Test("array element-wise — same prefix, first differing element decides")
  func arrayElementWiseFirstDifference() {
    let a = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
    let b = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(3))])

    #expect(a < b)
    #expect(!(b < a))
  }

  @Test("array element-wise — mixed type elements use type hierarchy")
  func arrayElementWiseMixedTypes() {
    let a = JSON.array([JSON.number(.integer(1)), JSON.boolean(true)])
    let b = JSON.array([JSON.number(.integer(1)), JSON.string("x")])

    // boolean(1) < string(5) per type hierarchy, so a < b
    #expect(a < b)
    #expect(!(b < a))
  }

  @Test("array element-wise — equal arrays are not less")
  func arrayElementWiseEqual() {
    let a = JSON.array([JSON.number(.integer(1)), JSON.string("x")])
    let b = JSON.array([JSON.number(.integer(1)), JSON.string("x")])

    #expect(!(a < b))
    #expect(!(b < a))
  }

  @Test("array element-wise — empty arrays are equal")
  func arrayElementWiseEmpty() {
    let empty1 = JSON.array([])
    let empty2 = JSON.array([])

    #expect(!(empty1 < empty2))
    #expect(!(empty2 < empty1))
  }
```

- [ ] **Step 2: Add object key-value edge case tests**

Add after the array tests:

```swift
  // MARK: - Object key-value comparison

  @Test("object key-value — same keys, different values")
  func objectKeyValueDifferentValues() {
    let a = JSON.object(["a": JSON.number(.integer(1))])
    let b = JSON.object(["a": JSON.number(.integer(2))])

    #expect(a < b)
    #expect(!(b < a))
  }

  @Test("object key-value — different keys sort and compare")
  func objectKeyValueDifferentKeys() {
    let a = JSON.object(["a": JSON.number(.integer(1))])
    let b = JSON.object(["b": JSON.number(.integer(1))])

    // "a" < "b" so a < b
    #expect(a < b)
    #expect(!(b < a))
  }

  @Test("object key-value — superset keys use count comparison")
  func objectKeyValueSupersetKeys() {
    let small = JSON.object(["a": JSON.number(.integer(1))])
    let big = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.number(.integer(2))])

    #expect(small < big)
    #expect(!(big < small))
  }

  @Test("object key-value — equal objects are not less")
  func objectKeyValueEqual() {
    let a = JSON.object(["a": JSON.number(.integer(1))])
    let b = JSON.object(["a": JSON.number(.integer(1))])

    #expect(!(a < b))
    #expect(!(b < a))
  }

  @Test("object key-value — empty objects are equal")
  func objectKeyValueEmpty() {
    let empty1 = JSON.object([:])
    let empty2 = JSON.object([:])

    #expect(!(empty1 < empty2))
    #expect(!(empty2 < empty1))
  }
```

- [ ] **Step 3: Run tests**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON/.claude/worktrees/type-hierarchy-fix
swift test 2>&1
```

Expected: All tests pass including the new edge case tests.

- [ ] **Step 4: Commit**

```bash
git add Tests/OrderedJSONTests/Operators/JSONComparisonEdgeCaseTests.swift
git commit -m "test: add edge case tests for element-wise array and key-value object comparison"
```

---

### Task 6: Final verification — full test suite and lint

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

```bash
cd /Volumes/Storage/Code/Projects/OrderedJSON/.claude/worktrees/type-hierarchy-fix
swift test 2>&1
```

Expected: All tests pass.

- [ ] **Step 2: Run SwiftFormat lint**

```bash
swift format lint --recursive --parallel -p . 2>&1
```

Expected: No lint errors.

- [ ] **Step 3: Run SwiftFormat format**

```bash
swift format format --recursive --parallel --in-place -p . 2>&1
```

Expected: No changes needed (or auto-fixes applied).

- [ ] **Step 4: Final commit if formatting changed anything**

```bash
git add -A
git commit -m "chore: apply formatting after review fixes"
```
