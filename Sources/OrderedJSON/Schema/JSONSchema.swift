import Foundation
import OrderedCollections

/// A compiled JSON Schema that can validate JSON documents against a schema.
///
/// Supports Draft 2020-12 (primary) and Draft 7 (backward compatibility).
///
/// ## Creating a schema
///
/// ```swift
/// let schemaJSON: JSON = .object([
///   "type": .string("object"),
///   "properties": .object([
///     "name": .object(["type": .string("string")]),
///     "age":  .object(["type": .string("integer"), "minimum": .number(.integer(0))])
///   ]),
///   "required": .array([.string("name")])
/// ])
///
/// let schema = try JSONSchema(schema: schemaJSON)
/// ```
///
/// ## Validating a document
///
/// ```swift
/// let doc: JSON = .object(["name": .string("Alice"), "age": .number(.integer(30))])
/// try schema.validate(doc)  // throws on first error
///
/// let result = schema.validation(of: doc)  // collect all errors
/// print(result.valid)  // true
/// ```
///
/// - Warning: Two semantically-equivalent schemas with differently-ordered keys
///   will produce different `Hashable` values, since `JSON` hashing is
///   structure-preserving.
public struct JSONSchema: Hashable, Sendable {
  /// The JSON Schema draft version to use for validation.
  public enum Draft: Hashable, Sendable {
    /// JSON Schema Draft 7 (2018). Widely deployed, used by OpenAPI 3.0.
    case draft7
    /// JSON Schema Draft 2020-12 (2022). The current standard.
    case draft202012
    /// Auto-detect the draft from the schema's `$schema` keyword.
    /// Defaults to `.draft202012` if no `$schema` is present.
    case auto
  }

  /// The schema JSON that was provided at init.
  internal let schemaJSON: JSON
  /// The resolved draft version.
  internal let draft: Draft
  /// The compiled schema with resolved `$ref`, `$defs`, `$id`, `$anchor`.
  internal let compiled: CompiledSchema?

  /// Creates a compiled JSON Schema from a JSON representation.
  ///
  /// The schema JSON is validated internally — malformed schemas (e.g., invalid
  /// regex patterns, non-object schemas) throw an error during init.
  ///
  /// - Parameters:
  ///   - schema: The JSON representation of the schema.
  ///   - draft: The draft version to use. Defaults to `.auto`.
  /// - Throws: `JSONSchemaError` if the schema itself is invalid.
  public init(schema: JSON, draft: Draft = .auto) throws {
    // Detect draft from $schema if auto
    let resolvedDraft: Draft
    if draft == .auto {
      resolvedDraft = JSONSchema.detectDraft(from: schema)
    } else {
      resolvedDraft = draft
    }

    // Validate schema structure
    guard schema.isObject || schema.isBoolean else {
      throw JSONSchemaError(
        instancePath: "",
        schemaPath: "",
        keyword: "schema",
        message: "Schema must be a JSON object or boolean"
      )
    }

    // Pre-compile regex patterns so invalid regexes fail at init time
    // rather than during validation. Boolean schemas have no patterns.
    if schema.isObject {
      try JSONSchema.validatePatterns(schema)
    }

    // Compile the schema for $defs, $ref, $id, $anchor support
    let compiled: CompiledSchema?
    if schema.isObject {
      compiled = CompiledSchema(schema: schema)
    } else {
      compiled = nil
    }

    self.schemaJSON = schema
    self.draft = resolvedDraft
    self.compiled = compiled
  }

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
  internal static func detectDraft(from schema: JSON) -> Draft {
    guard let schemaStr = schema["$schema"]?.stringValue else {
      return .draft202012
    }

    // Exact URI matching first (official spec links)
    if draft7URIs.contains(schemaStr) {
      return .draft7
    }
    if draft6URIs.contains(schemaStr) {
      // Draft 6 shares Draft 7 semantics for Phase 1 keywords;
      // default to 2020-12 for forward compatibility.
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

  // MARK: - Validation API

  /// Validates a JSON document against this schema and throws on the first
  /// validation error.
  ///
  /// - Parameter document: The JSON document to validate.
  /// - Returns: `true` if the document is valid.
  /// - Throws: `JSONSchemaError` — the first validation error encountered.
  public func validate(_ document: JSON) throws -> Bool {
    var errors: [JSONSchemaError] = []
    validateValue(
      document, against: schemaJSON, instancePath: "", schemaPath: "",
      errors: &errors, recursionDepth: 0)
    if let first = errors.first {
      throw first
    }
    return true
  }

  /// Validates a JSON document against this schema and returns a result
  /// containing **all** validation errors (if any). Does **not** throw.
  ///
  /// Use this when you need to inspect every error rather than fail-fast.
  ///
  /// - Parameter document: The JSON document to validate.
  /// - Returns: A `JSONSchemaResult` with all errors collected.
  public func validation(of document: JSON) -> JSONSchemaResult {
    var errors: [JSONSchemaError] = []
    validateValue(
      document, against: schemaJSON, instancePath: "", schemaPath: "",
      errors: &errors, recursionDepth: 0)
    return JSONSchemaResult(valid: errors.isEmpty, errors: errors)
  }

  /// Checks whether a JSON document is valid against this schema.
  /// Returns `true`/`false` without throwing.
  ///
  /// - Parameter document: The JSON document to validate.
  /// - Returns: `true` if the document is valid.
  public func isValid(_ document: JSON) -> Bool {
    var errors: [JSONSchemaError] = []
    validateValue(
      document, against: schemaJSON, instancePath: "", schemaPath: "",
      errors: &errors, recursionDepth: 0)
    return errors.isEmpty
  }

  // MARK: - Core validation

  /// Validates a single value against a subschema, collecting errors.
  /// Maximum recursion depth for schema validation.
  /// Prevents stack overflow from deeply nested or circular schemas.
  private static let maxRecursionDepth = 100

  internal func validateValue(
    _ value: JSON,
    against subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError],
    recursionDepth: Int = 0
  ) {
    // Recursion depth guard — prevents stack overflow from deeply nested schemas
    guard recursionDepth < Self.maxRecursionDepth else {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath,
          keyword: "schema",
          message: "maximum recursion depth exceeded"))
      return
    }

    let nextDepth = recursionDepth + 1

    if let boolVal = subschema.boolValue {
      if !boolVal {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath, keyword: "false",
            message: "boolean schema false rejects the value"))
      }
      return
    }
    guard subschema.isObject else { return }

    // Resolve $ref before processing keywords — $ref replaces the entire
    // subschema per spec (sibling keywords are ignored alongside $ref).
    if let refStr = subschema["$ref"]?.stringValue {
      if let target = compiled?.resolveRef(refStr) {
        validateValue(
          value, against: target, instancePath: instancePath,
          schemaPath: schemaPath + "/$ref", errors: &errors,
          recursionDepth: nextDepth)
      } else {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/$ref",
            keyword: "$ref",
            message: "unresolvable reference: '\(refStr)'"))
      }
      return
    }

    validateType(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateProperties(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateRequired(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateMinimum(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateMaximum(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateExclusiveMinimum(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateExclusiveMaximum(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateMultipleOf(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validatePattern(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateEnum(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateConst(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateMinLength(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateMaxLength(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateAllOf(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateAnyOf(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateOneOf(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateNot(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateIfThenElse(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateDependentSchemas(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateDependentRequired(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)

    // Array keywords
    validateItems(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validatePrefixItems(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateAdditionalItems(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateMinItems(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateMaxItems(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateUniqueItems(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateContains(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)

    // Object keywords
    validateMinProperties(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateMaxProperties(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validatePropertyNames(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validatePatternProperties(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateAdditionalProperties(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateUnevaluatedProperties(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateUnevaluatedItems(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
  }

  // MARK: - Schema-aware equality

  /// Compares two JSON values using schema-aware equality semantics.
  /// Integers compare equal to equal floats (`1` == `1.0`). Objects compare
  /// by key-value pairs ignoring key order.
  internal static func schemaEqual(_ lhs: JSON, _ rhs: JSON) -> Bool {
    switch (lhs.storage, rhs.storage) {
    case (.null, .null): return true
    case (.boolean(let a), .boolean(let b)): return a == b
    case (.number(.integer(let a)), .number(.integer(let b))): return a == b
    case (.number(.float(let a)), .number(.float(let b))): return a == b
    case (.number(.integer(let a)), .number(.float(let b))): return Double(a) == b
    case (.number(.float(let a)), .number(.integer(let b))): return a == Double(b)
    case (.string(let a), .string(let b)): return a == b
    case (.array(let a), .array(let b)):
      guard a.count == b.count else { return false }
      for (i, elem) in a.enumerated() { if !schemaEqual(elem, b[i]) { return false } }
      return true
    case (.object(let a), .object(let b)):
      guard a.count == b.count else { return false }
      for (key, value) in a {
        guard let bVal = b[key] else { return false }
        if !schemaEqual(value, bVal) { return false }
      }
      return true
    default: return false
    }
  }
}
