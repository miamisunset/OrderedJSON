# Type Hierarchy Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the comparison operator, docs, and tests to match nlohmann/json's actual type hierarchy: `null < boolean < number < object < array < string < binary`

**Architecture:** Add a private `typeOrder` helper in `JSON+Comparison.swift` that maps `Storage` cases to ordinals (null=0, boolean=1, number=2, object=3, array=4, string=5, binary=6). Replace the `default: return false` case in `<` with `return typeOrder(lhs.storage) < typeOrder(rhs.storage)`. Update README.md docs and fix edge-case tests to match correct cross-type behavior.

**Tech Stack:** Swift 6, OrderedJSON library, Swift Testing

---

### Task 1: Fix the comparison operator

**Files:**
- Modify: `Sources/OrderedJSON/Operators/JSON+Comparison.swift`

- [ ] **Step 1: Add `typeOrder` helper and update `<` operator**

Replace the file content with:

```swift
import Foundation
import OrderedCollections

// Comparable conformance is declared on JSON itself — the operators below
// satisfy Comparable's requirements (a < a is false, a < b implies !(b < a)).
// Cross-type comparisons use the nlohmann/json type hierarchy:
// null < boolean < number < object < array < string < binary

extension JSON {
  // MARK: - Type ordering (matching nlohmann/json semantics)

  /// Maps a `Storage` case to its comparison ordinal.
  ///
  /// nlohmann/json ordering:
  /// null(0) < boolean(1) < number(2) < object(3) < array(4) < string(5) < binary(6)
  private static func typeOrder(_ storage: Storage) -> Int {
    switch storage {
    case .null:    return 0
    case .boolean: return 1
    case .number:  return 2
    case .object:  return 3
    case .array:   return 4
    case .string:  return 5
    }
  }

  // MARK: - Comparison operators (matching nlohmann/json semantics)

  /// Less-than comparison.
  ///
  /// Matches nlohmann/json semantics:
  /// - Null is less than any non-null value.
  /// - Booleans: `false < true`.
  /// - Numbers are compared numerically with integer-to-float promotion.
  /// - Strings are compared lexicographically.
  /// - Arrays and objects are compared by count (shorter is smaller).
  /// - Different types compare by type hierarchy:
  ///   `null < boolean < number < object < array < string`
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side JSON value.
  ///   - rhs: The right-hand side JSON value.
  /// - Returns: `true` if `lhs` is less than `rhs`.
  public static func < (lhs: JSON, rhs: JSON) -> Bool {
    switch (lhs.storage, rhs.storage) {
    case (.null, .null): return false
    case (.null, _): return true
    case (_, .null): return false
    case (.boolean(let a), .boolean(let b)): return a == false && b == true
    case (.number(.integer(let a)), .number(.integer(let b))): return a < b
    case (.number(.float(let a)), .number(.float(let b))): return a < b
    case (.number(.integer(let a)), .number(.float(let b))): return Double(a) < b
    case (.number(.float(let a)), .number(.integer(let b))): return a < Double(b)
    case (.string(let a), .string(let b)): return a < b
    case (.array(let a), .array(let b)): return a.count < b.count
    case (.object(let a), .object(let b)): return a.count < b.count
    default:
      return typeOrder(lhs.storage) < typeOrder(rhs.storage)
    }
  }

  /// Less-than-or-equal comparison.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side JSON value.
  ///   - rhs: The right-hand side JSON value.
  /// - Returns: `true` if `lhs <= rhs`.
  public static func <= (lhs: JSON, rhs: JSON) -> Bool {
    lhs < rhs || lhs == rhs
  }

  /// Greater-than comparison.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side JSON value.
  ///   - rhs: The right-hand side JSON value.
  /// - Returns: `true` if `lhs > rhs`.
  public static func > (lhs: JSON, rhs: JSON) -> Bool {
    rhs < lhs
  }

  /// Greater-than-or-equal comparison.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side JSON value.
  ///   - rhs: The right-hand side JSON value.
  /// - Returns: `true` if `lhs >= rhs`.
  public static func >= (lhs: JSON, rhs: JSON) -> Bool {
    rhs < lhs || lhs == rhs
  }
}
```

- [ ] **Step 2: Run tests to verify existing tests still pass**

Run: `swift test`
Expected: All 1688 tests pass (existing tests only test same-type comparisons, which are unchanged)

- [ ] **Step 3: Commit**

```bash
git add Sources/OrderedJSON/Operators/JSON+Comparison.swift
git commit -m "fix: add typeOrder helper for cross-type comparison

Adds a private typeOrder(_:) helper that maps Storage cases to
nlohmann/json's type hierarchy ordinals. Changes the default case
in operator< from returning false to comparing by type order.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: Fix the edge-case tests

**Files:**
- Modify: `Tests/OrderedJSONTests/Operators/JSONComparisonEdgeCaseTests.swift`

- [ ] **Step 4: Update cross-type test assertions**

Replace the `crossTypeBoolVsNumber` test to assert boolean < number:

```swift
  @Test("cross-type boolean vs number — boolean < number per type hierarchy")
  func crossTypeBoolVsNumber() {
    let boolTrue = JSON.boolean(true)
    let boolFalse = JSON.boolean(false)
    let num = JSON.number(.integer(0))

    #expect(boolTrue < num)       // boolean < number
    #expect(num < boolTrue)       // number < boolean is false
    #expect(!(boolTrue > num))    // boolean > number is false
    #expect(num > boolTrue)       // number > boolean
    #expect(boolTrue <= num)      // boolean <= number
    #expect(!(num <= boolTrue))   // number <= boolean is false
    #expect(!(boolTrue >= num))   // boolean >= number is false
    #expect(num >= boolTrue)      // number >= boolean

    #expect(boolFalse < num)      // boolean(false) < number
    #expect(!(num < boolFalse))   // number < boolean(false) is false
  }
```

Replace the `crossTypeNumberVsString` test to assert number < object and number < string:

```swift
  @Test("cross-type number vs string — number < string per type hierarchy")
  func crossTypeNumberVsString() {
    let num = JSON.number(.integer(42))
    let str = JSON.string("hello")

    #expect(num < str)            // number < string
    #expect(!(str < num))         // string < number is false
    #expect(!(num > str))         // number > string is false
    #expect(str > num)            // string > number
    #expect(num <= str)           // number <= string
    #expect(!(str <= num))        // string <= number is false
    #expect(!(num >= str))        // number >= string is false
    #expect(str >= num)           // string >= number
  }
```

Replace the `crossTypeStringVsObject` test to assert object < string:

```swift
  @Test("cross-type string vs object — object < string per type hierarchy")
  func crossTypeStringVsObject() {
    let str = JSON.string("hello")
    let obj = JSON.object(["key": JSON.string("val")])

    #expect(obj < str)            // object < string
    #expect(!(str < obj))         // string < object is false
  }
```

- [ ] **Step 5: Update `typeOrdering` test**

Replace the test to assert the full hierarchy:

```swift
  @Test("type ordering — null < boolean < number < object < array < string")
  func typeOrdering() {
    #expect(JSON.null < JSON.boolean(true))
    #expect(JSON.boolean(false) < JSON.number(.integer(0)))
    #expect(JSON.number(.integer(0)) < JSON.object([:]))
    #expect(JSON.object([:]) < JSON.array([]))
    #expect(JSON.array([]) < JSON.string(""))

    // Reverse direction
    #expect(!(JSON.boolean(true) < JSON.null))
    #expect(!(JSON.number(.integer(0)) < JSON.boolean(true)))
    #expect(!(JSON.object([:]) < JSON.number(.integer(0))))
    #expect(!(JSON.array([]) < JSON.object([:])))
    #expect(!(JSON.string("") < JSON.array([])))
  }
```

- [ ] **Step 6: Add cross-type consistency test**

Add a new test at the end of the edge-case suite (before the `@Suite("Sequence Edge Case Tests")` line):

```swift
  @Test("cross-type — all type pairs respect hierarchy")
  func crossTypeAllPairs() {
    let types: [(JSON, String)] = [
      (.null, "null"),
      (.boolean(false), "boolean"),
      (.number(.integer(0)), "number"),
      (.object([:]), "object"),
      (.array([]), "array"),
      (.string(""), "string"),
    ]

    for i in 0..<types.count {
      for j in 0..<types.count {
        let a = types[i].0
        let b = types[j].0
        if i < j {
          #expect(a < b, "\(types[i].1) < \(types[j].1) should be true")
          #expect(!(b < a), "\(types[j].1) < \(types[i].1) should be false")
        } else if i == j {
          #expect(!(a < b), "\(types[i].1) < \(types[i].1) should be false")
        } else {
          #expect(!(a < b), "\(types[i].1) < \(types[j].1) should be false")
          #expect(b < a, "\(types[j].1) < \(types[i].1) should be true")
        }
      }
    }
  }
```

- [ ] **Step 7: Run tests to verify updated tests pass**

Run: `swift test`
Expected: All tests pass, including the newly corrected cross-type assertions

- [ ] **Step 8: Commit**

```bash
git add Tests/OrderedJSONTests/Operators/JSONComparisonEdgeCaseTests.swift
git commit -m "fix: update comparison tests to match nlohmann/json type hierarchy

Cross-type comparisons now follow null < boolean < number < object <
array < string ordering. Updates all tests that asserted the broken
behavior and adds a comprehensive cross-type pair test.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 3: Fix the README docs

**Files:**
- Modify: `README.md`

- [ ] **Step 9: Fix hierarchy claim in type checks section**

At line 513, change:
```
The type hierarchy follows `nlohmann/json`: `null < boolean < number < string < object < array`. This ordering is used by comparison operators (see Comparison section).
```
To:
```
The type hierarchy follows `nlohmann/json`: `null < boolean < number < object < array < string`. This ordering is used by comparison operators (see Comparison section).
```

- [ ] **Step 10: Fix hierarchy in Comparison section**

At lines 814-817, change:
```
nlohmann/json defines a strict type hierarchy:

```
null < boolean < number < string < object < array
```
```
To:
```
nlohmann/json defines a strict type hierarchy:

```
null < boolean < number < object < array < string
```
```

- [ ] **Step 11: Fix type ordering examples**

At lines 820-830, change:
```
This means `JSON.null < JSON.boolean(true)` is true, and `JSON.null < JSON.string("x")` is true. Objects compare by key count first, then by each key-value pair. Arrays compare by element count first, then by each element.

```swift
// Type ordering examples (same-type comparisons only)
JSON.null < JSON.boolean(true)                // true (null < any non-null)
JSON.boolean(false) < JSON.boolean(true)       // true
JSON.number(.integer(1)) < JSON.number(.integer(2))  // true
JSON.string("a") < JSON.string("b")            // true
JSON.object(["x": JSON(1)]) < JSON.object(["x": JSON(1), "y": JSON(2)]) // true (by count)
JSON.array([JSON(1)]) < JSON.array([JSON(1), JSON(2)]) // true (by count)
```
```
To:
```
This means `JSON.null < JSON.boolean(true)` is true, and `JSON.null < JSON.string("x")` is true. Cross-type comparisons follow the type hierarchy, so `boolean < number`, `number < object`, `object < array`, and `array < string` are all true. Objects compare by key count first, then by each key-value pair. Arrays compare by element count first, then by each element.

```swift
// Type ordering examples
JSON.null < JSON.boolean(true)                  // true (null < boolean)
JSON.boolean(false) < JSON.number(.integer(0))   // true (boolean < number)
JSON.number(.integer(0)) < JSON.object([:])      // true (number < object)
JSON.object([:]) < JSON.array([])                // true (object < array)
JSON.array([]) < JSON.string("")                 // true (array < string)
JSON.null < JSON.string("x")                     // true (null < string)
JSON.number(.integer(1)) < JSON.number(.integer(2))  // true (same type, by value)
JSON.string("a") < JSON.string("b")              // true (same type, lexicographic)
JSON.object(["x": JSON(1)]) < JSON.object(["x": JSON(1), "y": JSON(2)]) // true (same type, by count)
JSON.array([JSON(1)]) < JSON.array([JSON(1), JSON(2)]) // true (same type, by count)
```
```

- [ ] **Step 12: Verify docs look correct**

Run: `grep -n "null < boolean < number" README.md`
Expected: All occurrences show `null < boolean < number < object < array < string` (not the old ordering)

- [ ] **Step 13: Commit**

```bash
git add README.md
git commit -m "docs: fix type hierarchy ordering in README

Corrects the documented ordering from null < boolean < number < string
< object < array to null < boolean < number < object < array < string
to match nlohmann/json's actual semantics. Updates cross-type examples.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: Final verification

- [ ] **Step 14: Run full test suite**

Run: `swift test`
Expected: All tests pass

- [ ] **Step 15: Run lint and format**

Run: `swift format lint --recursive --parallel -p .` then `swift format format --recursive --parallel --in-place -p .`
Expected: No lint errors, formatting passes cleanly

- [ ] **Step 16: Final commit if formatting changes**

```bash
git add -A
git commit -m "chore: apply formatting after type hierarchy fix

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```
