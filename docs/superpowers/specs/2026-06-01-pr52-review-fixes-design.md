# PR #52 Self-Review Fixes

**Date:** 2026-06-01
**Status:** Approved design

## Summary

Address 5 issues raised in the self-review of PR #52 (typed `JSONSchemaKeyword` enum migration):

1. Remove unrelated dump-indent plan/spec docs from the branch
2. Migrate `keywordCache` inner dictionary type from `[String: JSON]` to `[JSONSchemaKeyword: JSON]`
3. Replace `rawValue` comparison in `hasOtherKeys` check with direct enum comparison
4. Extract repeated `[.allOf, .anyOf, .oneOf]` into a shared static constant
5. Strengthen `keywordAllValidationCases()` test assertion

## Scope

All changes are in the `Sources/OrderedJSON/Schema/` directory and `Tests/OrderedJSONTests/Schema/` directory. No new features — only type-safety and cleanup fixes.

## Changes

### Issue 1: Remove unrelated docs

Delete two files from the branch:
- `docs/superpowers/plans/2026-05-31-dump-indent-redesign.md`
- `docs/superpowers/specs/2026-05-31-dump-indent-design.md`

These describe a separate feature (dump indent API redesign) and add ~1300 lines of noise to the PR diff.

### Issue 2: Type-safe keywordCache

**Current:**
```swift
let keywordCache: [String: [String: JSON]]
// Accessor uses rawValue bridge:
cache[key.rawValue]
```

**Target:**
```swift
let keywordCache: [String: [JSONSchemaKeyword: JSON]]
// Accessor uses enum key directly:
cache[key]
```

Update `buildKeywordCacheRecursive` to use `JSONSchemaKeyword` keys when collecting keyword values. The inner loop currently iterates raw string keys from the JSON object dict — need to convert each string key to `JSONSchemaKeyword` (using the enum's `init?(rawValue:)` failable init, or the typed subscript on `JSON`).

### Issue 3: hasOtherKeys rawValue comparison

**Current** (Validation.swift:323):
```swift
hasOtherKeys = dict.keys.contains(where: { $0 != JSONSchemaKeyword.dollarRef.rawValue })
```

**Target:**
```swift
hasOtherKeys = dict.keys.contains { $0 != "$ref" }
```

Since `dict.keys` are `String`, compare against the literal `"$ref"` directly. This avoids `.rawValue` entirely and is clearer about intent.

### Issue 4: Composition keywords constant

Add to `JSONSchemaKeyword`:
```swift
public static let compositionKeywords: [JSONSchemaKeyword] = [.allOf, .anyOf, .oneOf]
```

Replace all inline array literals:
- `JSONSchema+Compilation.swift:132` (in `buildKeywordCacheRecursive`)
- `JSONSchemaPatterns.swift:45`
- Any other files

### Issue 5: Stronger validationKeywords test

**Current:**
```swift
let allValidationKeywords: Set<JSONSchemaKeyword> = [...]
#expect(allValidationKeywords.count == 41)
```

**Target:**
Change `validationKeywords` from a `private static let` on `JSONSchema` to a `package static let` so the test can reference it directly. Then update the test to assert the test set equals the production set:

```swift
#expect(allValidationKeywords == JSONSchema.validationKeywords)
```

## Testing

- All 1691 existing tests must continue to pass
- No new feature tests needed — these are type-safety and cleanup changes
- Verify the keyword cache migration doesn't change behavior: the cache values are the same, only the key type changes
