import Foundation
import OrderedCollections

extension JSONSchema {

  // MARK: - Draft detection

  /// Official JSON Schema draft URIs for exact matching.
  private static let draft7URIs: Set<String> = [
    "http://json-schema.org/draft-07/schema#",
    "http://json-schema.org/draft-07/schema",
    "https://json-schema.org/draft-07/schema#",
    "https://json-schema.org/draft-07/schema",
  ]

  private static let draft6URIs: Set<String> = [
    "http://json-schema.org/draft-06/schema#",
    "http://json-schema.org/draft-06/schema",
    "https://json-schema.org/draft-06/schema#",
    "https://json-schema.org/draft-06/schema",
  ]

  private static let draft202012URIs: Set<String> = [
    "https://json-schema.org/draft/2020-12/schema",
    "https://json-schema.org/draft/2020-12/schema#",
    "http://json-schema.org/draft/2020-12/schema",
    "http://json-schema.org/draft/2020-12/schema#",
  ]

  /// Detects the JSON Schema draft from the `$schema` keyword.
  /// - Parameter schema: The schema JSON.
  /// - Returns: The detected draft, or `.draft202012` if unknown/missing.

  // MARK: - Vocabulary keyword mapping

  /// Maps standard vocabulary URLs to their keyword names.
  /// Used by `$vocabulary` support to determine which keywords are enabled.
  private static let vocabularyKeywords: [String: Set<JSONSchemaKeyword>] = [
    // Core vocabulary
    "https://json-schema.org/draft/2020-12/vocab/core": [
      .dollarId, .dollarSchema, .dollarRef, .dollarAnchor, .dollarDynamicRef,
      .dollarDynamicAnchor, .dollarVocabulary, .dollarComment, .dollarDefs,
    ],
    // Applicator vocabulary
    "https://json-schema.org/draft/2020-12/vocab/applicator": [
      .prefixItems, .items, .contains, .additionalProperties,
      .properties, .patternProperties, .dependentSchemas, .propertyNames,
      .if, .then, .else, .allOf, .anyOf, .oneOf, .not,
    ],
    // Validation vocabulary
    "https://json-schema.org/draft/2020-12/vocab/validation": [
      .type, .const, .enum, .multipleOf, .maximum, .exclusiveMaximum,
      .minimum, .exclusiveMinimum, .maxLength, .minLength, .pattern,
      .maxItems, .minItems, .uniqueItems, .contains, .maxContains,
      .minContains, .maxProperties, .minProperties, .required,
      .dependentRequired,
    ],
    // Unevaluated vocabulary
    "https://json-schema.org/draft/2020-12/vocab/unevaluated": [
      .unevaluatedItems, .unevaluatedProperties,
    ],
    // Format-annotation vocabulary
    "https://json-schema.org/draft/2020-12/vocab/format-annotation": [
      .format
    ],
    // Content vocabulary
    "https://json-schema.org/draft/2020-12/vocab/content": [
      .contentMediaType, .contentEncoding, .contentSchema,
    ],
    // Meta-data vocabulary
    "https://json-schema.org/draft/2020-12/vocab/meta-data": [
      .title, .description, .default, .examples, .readOnly, .writeOnly,
      .deprecated,
    ],
  ]

  /// Resolves a `$vocabulary` declaration from a metaschema and returns
  /// the set of enabled keywords. Keywords from vocabularies marked `false`
  /// are excluded.
  package static func enabledKeywords(from metaschema: JSON) -> Set<JSONSchemaKeyword>? {
    guard let vocabulary = metaschema[key: .dollarVocabulary]?.objectValue else { return nil }
    var enabled = Set<JSONSchemaKeyword>()
    for (vocabURL, enabledFlag) in vocabulary {
      guard let flag = enabledFlag.boolValue, flag else { continue }
      if let keywords = vocabularyKeywords[vocabURL] {
        enabled.formUnion(keywords)
      }
    }
    return enabled
  }

  static func detectDraft(from schema: JSON) -> Draft {
    guard let schemaStr = schema[key: .dollarSchema]?.stringValue else {
      return .draft202012
    }

    // Exact URI matching first (official spec links)
    if draft7URIs.contains(schemaStr) {
      return .draft7
    }
    if draft6URIs.contains(schemaStr) {
      // Draft 6 shares Draft 7 semantics; default to 2020-12 for forward compatibility.
      return .draft202012
    }
    if draft202012URIs.contains(schemaStr) {
      return .draft202012
    }

    // Fall back to substring matching for non-standard URIs
    if schemaStr.contains("draft-07") || schemaStr.contains("draft-7") {
      return .draft7
    }
    if schemaStr.contains("2020-12") || schemaStr.contains("draft/2020-12") {
      return .draft202012
    }

    // Default to latest
    return .draft202012
  }
}
