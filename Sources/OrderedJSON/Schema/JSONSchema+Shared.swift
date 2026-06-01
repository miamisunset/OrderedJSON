import Foundation
import OrderedCollections

// MARK: - JSONSchemaKeyword

/// A typed representation of JSON Schema keyword names.
///
/// Using this enum instead of raw string keys prevents typos and enables
/// autocomplete. Use with the `subscript(key:)` overload on `JSON`:
///
/// ```swift
/// subschema[key: .type]
/// subschema[key: .properties]
/// subschema[key: .dollarRef]
/// ```
public enum JSONSchemaKeyword: String, Hashable, Sendable, CaseIterable {
  // MARK: - Meta-keywords ($-prefixed → camelCase with "dollar" prefix)

  /// `$id` — schema resource identifier
  case dollarId = "$id"
  /// `$ref` — JSON Schema reference
  case dollarRef = "$ref"
  /// `$defs` — shared schema definitions
  case dollarDefs = "$defs"
  /// `$anchor` — plain-name anchor
  case dollarAnchor = "$anchor"
  /// `$dynamicAnchor` — dynamic-scope anchor
  case dollarDynamicAnchor = "$dynamicAnchor"
  /// `$dynamicRef` — dynamic-scope reference
  case dollarDynamicRef = "$dynamicRef"
  /// `$schema` — metaschema URI
  case dollarSchema = "$schema"
  /// `$vocabulary` — vocabulary declaration
  case dollarVocabulary = "$vocabulary"
  /// `$comment` — annotation comment
  case dollarComment = "$comment"

  // MARK: - Validation keywords

  /// `type` — value type constraint
  case type
  /// `const` — exact value constraint
  case `const`
  /// `enum` — allowed values list
  case `enum`
  /// `multipleOf` — divisor constraint
  case multipleOf
  /// `maximum` — numeric upper bound
  case maximum
  /// `exclusiveMaximum` — strict numeric upper bound
  case exclusiveMaximum
  /// `minimum` — numeric lower bound
  case minimum
  /// `exclusiveMinimum` — strict numeric lower bound
  case exclusiveMinimum
  /// `maxLength` — maximum string length
  case maxLength
  /// `minLength` — minimum string length
  case minLength
  /// `pattern` — regex string constraint
  case pattern
  /// `format` — string format constraint (Draft 7 assertion)
  case format
  /// `maxItems` — maximum array length
  case maxItems
  /// `minItems` — minimum array length
  case minItems
  /// `uniqueItems` — array uniqueness constraint
  case uniqueItems
  /// `maxContains` — maximum matching items in contains
  case maxContains
  /// `minContains` — minimum matching items in contains
  case minContains
  /// `maxProperties` — maximum object property count
  case maxProperties
  /// `minProperties` — minimum object property count
  case minProperties
  /// `required` — required property names
  case required
  /// `dependentRequired` — conditional required properties (Draft 2020-12)
  case dependentRequired

  // MARK: - Applicator keywords

  /// `properties` — property-schema map
  case properties
  /// `patternProperties` — regex-keyed property schemas
  case patternProperties
  /// `additionalProperties` — schema for extra properties
  case additionalProperties
  /// `propertyNames` — schema for property name strings
  case propertyNames
  /// `dependentSchemas` — conditional object schemas (Draft 2020-12)
  case dependentSchemas
  /// `items` — array item schema (or tuple in Draft 7)
  case items
  /// `prefixItems` — tuple schemas for first items (Draft 2020-12)
  case prefixItems
  /// `additionalItems` — schema for extra tuple items (Draft 7)
  case additionalItems
  /// `unevaluatedItems` — schema for items not evaluated by other keywords
  case unevaluatedItems
  /// `unevaluatedProperties` — schema for properties not evaluated by other keywords
  case unevaluatedProperties
  /// `contains` — array must contain matching item
  case contains
  /// `allOf` — all subschemas must match
  case allOf
  /// `anyOf` — at least one subschema must match
  case anyOf
  /// `oneOf` — exactly one subschema must match
  case oneOf
  /// `not` — subschema must not match
  case not
  /// `if` — conditional schema branch
  case `if`
  /// `then` — schema when `if` matches
  case `then`
  /// `else` — schema when `if` fails
  case `else`

  // MARK: - Content keywords (Draft 2020-12)

  /// `contentMediaType` — media type of the content
  case contentMediaType
  /// `contentEncoding` — encoding of the content
  case contentEncoding
  /// `contentSchema` — schema for decoded content
  case contentSchema

  // MARK: - Annotation keywords

  /// `title` — schema title
  case title
  /// `description` — schema description
  case description
  /// `default` — default value
  case `default`
  /// `examples` — example values
  case examples
  /// `readOnly` — read-only flag
  case readOnly
  /// `writeOnly` — write-only flag
  case writeOnly
  /// `deprecated` — deprecation flag
  case deprecated

  // MARK: - Draft 7 legacy keywords

  /// `dependencies` — Draft 7 property dependencies
  case dependencies
  /// `definitions` — Draft 7 shared definitions (superseded by $defs)
  case definitions
}

extension JSON {
  /// Accesses a schema keyword value from a JSON object using the typed
  /// `JSONSchemaKeyword` enum instead of a raw string key.
  ///
  /// ```swift
  /// subschema[key: .type]     // instead of subschema["type"]
  /// subschema[key: .minimum]  // instead of subschema["minimum"]
  /// ```
  subscript(key schemaKeyword: JSONSchemaKeyword) -> JSON? {
    self[schemaKeyword.rawValue]
  }
}

extension JSONSchema {
  // ======================================================================
  // MARK: - Shared validators (called for both drafts, no draft checks)
  // ======================================================================
}
