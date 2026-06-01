# Fix Type Hierarchy in Comparison Operators

## Problem

The docs in `README.md` claim the type hierarchy follows nlohmann/json as `null < boolean < number < string < object < array`. However, nlohmann/json's actual ordering (confirmed from C++ source) is **`null < boolean < number < object < array < string < binary`**.

Two discrepancies:
1. **String is LAST** among standard types, not between number and object/array
2. **Object precedes array** (object < array), not the reverse

Furthermore, the `<` operator implementation returns `false` for all cross-type comparisons (except null vs anything), which is incorrect. Cross-type comparisons should compare by type order.

## Changes

### 1. Comparison operator (`Sources/OrderedJSON/Operators/JSON+Comparison.swift`)

Add a private `typeOrder` helper mapping Storage cases to ordinals matching nlohmann/json:

```
null → 0, boolean → 1, number → 2, object → 3, array → 4, string → 5
```

Replace `default: return false` in `<` with `default: return typeOrder(lhs.storage) < typeOrder(rhs.storage)`.

Update the doc comment on `<` to reflect the correct hierarchy.

Binary ordinal (6) is reserved for future binary support but not wired into any Storage case yet.

### 2. Docs (`README.md`)

- Line 513: `null < boolean < number < string < object < array` → `null < boolean < number < object < array < string`
- Lines 814-817: Same correction in the Comparison section
- Lines 820-830: Update examples to show cross-type comparisons (boolean < number, number < object, etc.)

### 3. Tests (`Tests/OrderedJSONTests/Operators/JSONComparisonEdgeCaseTests.swift`)

- `crossTypeBoolVsNumber`: Change assertions — boolean < number is true
- `crossTypeNumberVsString`: number < object is true, number < string is true
- `crossTypeStringVsObject`: string < object is false, object < string is true
- `typeOrdering`: Update to assert full hierarchy: null < boolean < number < object < array < string
- Add new test: cross-type comparisons for every pair in the hierarchy

### 4. Binary

No `Storage.binary` case exists yet. The typeOrder helper includes a `return 6` for binary so it works when added later. No other changes needed.

## Files touched

- `Sources/OrderedJSON/Operators/JSON+Comparison.swift` — comparison logic
- `README.md` — docs
- `Tests/OrderedJSONTests/Operators/JSONComparisonEdgeCaseTests.swift` — tests
