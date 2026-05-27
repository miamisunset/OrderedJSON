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
/// Remote schemas can be pre-registered for `$ref` resolution:
///
/// ```swift
/// let schema = try JSONSchema(schema: schemaJSON, remoteSchemas: [
///   "http://example.com/schema.json": someRemoteSchemaJSON
/// ])
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
  /// Remote compiled schemas pre-registered for `$ref` resolution, keyed by
  /// URL. When a `$ref` cannot be resolved locally, these are consulted.
  internal let remoteCompiled: [String: CompiledSchema]
  /// Options for format validation (which formats to enable/disable).
  internal let formatOptions: JSONSchemaFormatOptions

  /// The output mode for validation results.
  internal let outputMode: OutputMode

  /// Controls the detail level of validation results.
  ///
  /// - `.basic` (default): flat list of errors with path, keyword, message.
  /// - `.verbose`: hierarchical errors grouped by schema path, with failed
  ///   value and parent schema information.
  public enum OutputMode: Hashable, Sendable {
    /// Flat list of errors with instance path, schema path, keyword, message.
    case basic
    /// Hierarchical errors with nested sub-errors for composition keywords.
    case verbose
  }

  /// Creates a compiled JSON Schema from a JSON representation.
  ///
  /// The schema JSON is validated internally — malformed schemas (e.g., invalid
  /// regex patterns, non-object schemas) throw an error during init.
  ///
  /// - Parameters:
  ///   - schema: The JSON representation of the schema.
  ///   - draft: The draft version to use. Defaults to `.auto`.
  ///   - formatOptions: Options for format validation. Defaults to all enabled.
  ///   - outputMode: The output mode for validation results. Defaults to `.basic`.
  ///   - remoteSchemas: Remote schemas pre-registered for `$ref` resolution,
  ///     keyed by URL. These are compiled internally for efficient resolution.
  ///     Defaults to empty.
  /// - Throws: `JSONSchemaError` if the schema itself is invalid.
  public init(
    schema: JSON, draft: Draft = .auto,
    formatOptions: JSONSchemaFormatOptions = JSONSchemaFormatOptions(),
    outputMode: OutputMode = .basic,
    remoteSchemas: [String: JSON] = [:]
  ) throws {
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
      compiled = try CompiledSchema(schema: schema)
    } else {
      compiled = nil
    }

    // Compile remote schemas for efficient resolution.
    // Also register all resource URIs from each remote schema so that
    // $ref to URIs defined via $id within the remote schema resolve.
    var remoteCompiled: [String: CompiledSchema] = [:]
    for (url, remoteJSON) in remoteSchemas {
      if remoteJSON.isObject {
        do {
          let compiled = try CompiledSchema(schema: remoteJSON)
          // Register the file URL itself
          remoteCompiled[url] = compiled
          // Also register all resource URIs from this remote schema.
          // Each resource URI (including empty string for root) is resolved
          // against the file URL to form the absolute key.
          for (resourceURI, _) in compiled.resources {
            let absoluteURI = CompiledSchema.resolveRelativeID(resourceURI, parent: url)
            remoteCompiled[absoluteURI] = compiled
          }
        } catch {
          // Skip invalid remote schemas silently
        }
      }
    }

    self.schemaJSON = schema
    self.draft = resolvedDraft
    self.compiled = compiled
    self.remoteCompiled = remoteCompiled
    self.formatOptions = formatOptions
    self.outputMode = outputMode
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
      errors: &errors, ctx: EvaluationContext())
    if let first = errors.first {
      throw first
    }
    return true
  }

  /// Validates a JSON document against this schema and returns a result
  /// containing **all** validation errors (if any). Does **not** throw.
  ///
  /// When `outputMode` is `.verbose`, the result includes hierarchical
  /// error trees via `verboseErrors`. Use `VerboseResult.errors` for a
  /// flat list regardless of mode.
  ///
  /// - Parameter document: The JSON document to validate.
  /// - Returns: A `VerboseResult` with all errors collected.
  public func validation(of document: JSON) -> VerboseResult {
    var errors: [JSONSchemaError] = []
    validateValue(
      document, against: schemaJSON, instancePath: "", schemaPath: "",
      errors: &errors, ctx: EvaluationContext())
    let verboseErrors: [VerboseError]
    if outputMode == .verbose {
      verboseErrors = buildVerboseErrors(from: errors)
    } else {
      verboseErrors = []
    }
    return VerboseResult(
      valid: errors.isEmpty,
      errors: errors,
      verboseErrors: verboseErrors)
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
      errors: &errors, ctx: EvaluationContext())
    return errors.isEmpty
  }

  // MARK: - Verbose output

  /// Builds hierarchical error trees from a flat list of errors.
  /// Groups errors by their first schema path segment (e.g., `/allOf`,
  /// `/properties/name`), nesting child errors under their parent.
  ///
  /// Within each group, the error whose keyword best matches the group
  /// key (e.g., keyword `"allOf"` for group `allOf`) is used as the parent.
  /// If no keyword matches, the first error alphabetically is used.
  internal func buildVerboseErrors(from errors: [JSONSchemaError]) -> [VerboseError] {
    // Group errors by their first schema-path segment
    var groups: [String: [JSONSchemaError]] = [:]
    for error in errors {
      let segments = error.schemaPath.split(separator: "/", omittingEmptySubsequences: true)
      let groupKey: String
      if let first = segments.first {
        groupKey = String(first)
      } else {
        groupKey = ""
      }
      groups[groupKey, default: []].append(error)
    }

    // Sort groups by schema path for deterministic output
    let sortedKeys = groups.keys.sorted()
    var result: [VerboseError] = []
    for key in sortedKeys {
      let groupErrors = groups[key]!
      // Prefer an error whose keyword matches the group key as parent.
      // This ensures composition keyword errors (e.g., keyword "allOf"
      // for group "allOf") are used as the parent when present.
      let parentIndex = groupErrors.firstIndex(where: { $0.keyword == key }) ?? 0
      let parent = groupErrors[parentIndex]
      let children = groupErrors.enumerated().filter { $0.offset != parentIndex }.map {
        VerboseError(error: $0.element)
      }
      if children.isEmpty {
        result.append(VerboseError(error: parent))
      } else {
        result.append(VerboseError(error: parent, children: children))
      }
    }
    return result
  }

  // MARK: - Core validation

  /// Validates a single value against a subschema, collecting errors.
  /// Maximum recursion depth for schema validation.
  /// Prevents stack overflow from deeply nested or circular schemas.
  /// Conservative; revisit if OpenAPI/AsyncAPI corpora hit the wall.
  private static let maxRecursionDepth = 20

  internal func validateValue(
    _ value: JSON,
    against subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError],
    ctx: EvaluationContext
  ) {
    // Recursion depth guard — prevents stack overflow from deeply nested schemas
    guard ctx.recursionDepth < Self.maxRecursionDepth else {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath,
          keyword: "schema",
          message: "maximum recursion depth exceeded"))
      return
    }

    // Determine the resource scope URI for this subschema.
    // If the subschema declares $id, use that; otherwise inherit from parent.
    // Resolve $id against the parent resource URI per RFC 3986
    let resourceURI: String
    if let idVal = subschema["$id"]?.stringValue {
      resourceURI = CompiledSchema.resolveRelativeID(idVal, parent: ctx.currentResourceURI)
    } else {
      resourceURI = ctx.currentResourceURI
    }

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

    // Compute the validation context for this subschema — increment recursion
    // depth, push any $dynamicAnchor onto the scope stack, and update the
    // current resource URI from the subschema's $id (if present).
    let currentCtx: EvaluationContext
    if let dynAnchorStr = subschema["$dynamicAnchor"]?.stringValue,
      compiled != nil
    {
      currentCtx = ctx.advanced(
        withAnchor: dynAnchorStr, schema: subschema, resourceURI: resourceURI)
    } else {
      currentCtx = ctx.advanced(resourceURI: resourceURI)
    }

    // Resolve $dynamicRef before $ref — $dynamicRef takes priority per spec.
    if let dynRefStr = subschema["$dynamicRef"]?.stringValue {
      if let resolved = compiled?.resolveDynamicRef(
        dynRefStr, dynamicScope: currentCtx.dynamicScope, currentResourceURI: resourceURI,
        remoteRegistry: remoteCompiled)
      {
        let resolvedCtx = currentCtx.advanced(resourceURI: resolved.resourceURI)
        validateValue(
          value, against: resolved.schema, instancePath: instancePath,
          schemaPath: schemaPath + "/$dynamicRef", errors: &errors,
          ctx: resolvedCtx)
      } else {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/$dynamicRef",
            keyword: "$dynamicRef",
            message: "unresolvable dynamic reference: '\(dynRefStr)'"))
      }
      // In Draft 2020-12, $dynamicRef does not skip sibling keywords
      // (unevaluatedItems, unevaluatedProperties still apply).
      // In Draft 7, $dynamicRef is not defined, so this code is unreachable.
      // Fall through to process sibling keywords.
    }

    // Resolve $ref before processing keywords.
    // In Draft 7, $ref replaces the entire subschema (sibling keywords ignored).
    // In Draft 2020-12, $ref is resolved AND sibling keywords are also processed
    // (unevaluatedItems, unevaluatedProperties, etc. still apply).
    if let refStr = subschema["$ref"]?.stringValue {
      if let resolved = compiled?.resolveRef(refStr, currentResourceURI: resourceURI,
        remoteRegistry: remoteCompiled) {
        let resolvedCtx = currentCtx.advanced(resourceURI: resolved.resourceURI)
        validateValue(
          value, against: resolved.schema, instancePath: instancePath,
          schemaPath: schemaPath + "/$ref", errors: &errors,
          ctx: resolvedCtx)
      } else {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/$ref",
            keyword: "$ref",
            message: "unresolvable reference: '\(refStr)'"))
      }
      // In Draft 7, return here — sibling keywords are ignored alongside $ref.
      // In Draft 2020-12, continue processing sibling keywords below.
      if draft == .draft7 { return }
    }

    // MARK: - Shared keyword dispatch (called for both drafts)

    validateType(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateProperties(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateRequired(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateMinimum(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateMaximum(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateMultipleOf(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validatePattern(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateEnum(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateConst(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateMinLength(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateMaxLength(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateAllOf(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateAnyOf(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateOneOf(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateNot(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateIfThenElse(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateMinItems(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateMaxItems(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateUniqueItems(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateContains(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateMinProperties(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateMaxProperties(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validatePropertyNames(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validatePatternProperties(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateAdditionalProperties(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)

    // MARK: - Items schema mode (shared — called for both drafts)
    // Draft 2020-12: applies to items beyond prefixItems.
    // Draft 7: applies to all items (prefixItems absent).

    validateItemsSchema(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)

    // MARK: - Exclusive min/max (numeric bound — shared)

    validateExclusiveMinimum(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)
    validateExclusiveMaximum(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors, ctx: currentCtx)

    // MARK: - Draft-specific keyword dispatch

    switch draft {
    case .draft7:
      // Draft 7 specific keywords.
      // Note: validateExclusiveMinimum/validateExclusiveMaximum (numeric)
      // are already called in the shared dispatch above.
      // validateItemsSchema (schema mode) is called by both drafts —
      // for Draft 7 it acts as schema-mode items (prefixItems absent).
      validateExclusiveMinimumBool(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateExclusiveMaximumBool(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateFormat(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateDependencies(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateItemsTuple(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateAdditionalItems(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)

    case .draft202012:
      validateExclusiveMinimum(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateExclusiveMaximum(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateDependentSchemas(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateDependentRequired(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validatePrefixItems(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateUnevaluatedItems(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateUnevaluatedProperties(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateContentMediaType(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateContentEncoding(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateContentSchema(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateMinContains(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)
      validateMaxContains(
        value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
        errors: &errors, ctx: currentCtx)

    default:
      break
    }
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
    case (.string(let a), .string(let b)):
      // Compare at Unicode scalar level, not canonical equivalence
      let sa = a.unicodeScalars
      let sb = b.unicodeScalars
      guard sa.count == sb.count else { return false }
      for (scalarA, scalarB) in zip(sa, sb) {
        if scalarA.value != scalarB.value { return false }
      }
      return true
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
