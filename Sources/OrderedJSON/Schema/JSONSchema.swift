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
/// let result = schema.validating(doc)  // collect all errors
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
  let schemaJSON: JSON
  /// The resolved draft version.
  let draft: Draft
  /// The compiled schema with resolved `$ref`, `$defs`, `$id`, `$anchor`.
  let compiled: CompiledSchema?
  /// Cache for resolved `$ref` targets to avoid repeated resolution.
  let refCache: RefCache?
  /// Remote compiled schemas pre-registered for `$ref` resolution, keyed by
  /// URL. When a `$ref` cannot be resolved locally, these are consulted.
  let remoteCompiled: [String: CompiledSchema]
  /// Options for format validation (which formats to enable/disable).
  let formatOptions: JSONSchemaFormatOptions

  /// The output mode for validation results.
  let outputMode: OutputMode

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

    // Create a ref cache for faster $ref resolution at runtime.
    let refCache: RefCache?
    if compiled != nil {
      refCache = RefCache()
    } else {
      refCache = nil
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
            let absoluteURI = CompiledSchema.resolveRelativeID(resourceURI, parentBaseURI: url)
            remoteCompiled[absoluteURI] = compiled
          }
        } catch {
          // Skip invalid remote schemas silently
        }
      }
    }
    self.remoteCompiled = remoteCompiled

    schemaJSON = schema
    self.draft = resolvedDraft
    self.compiled = compiled
    self.refCache = refCache
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
  // MARK: - Vocabulary keyword mapping

  /// Maps standard vocabulary URLs to their keyword names.
  /// Used by `$vocabulary` support to determine which keywords are enabled.
  private static let vocabularyKeywords: [String: Set<String>] = [
    // Core vocabulary
    "https://json-schema.org/draft/2020-12/vocab/core": [
      "$id", "$schema", "$ref", "$anchor", "$dynamicRef", "$dynamicAnchor",
      "$vocabulary", "$comment", "$defs",
    ],
    // Applicator vocabulary
    "https://json-schema.org/draft/2020-12/vocab/applicator": [
      "prefixItems", "items", "contains", "additionalProperties",
      "properties", "patternProperties", "dependentSchemas", "propertyNames",
      "if", "then", "else", "allOf", "anyOf", "oneOf", "not",
    ],
    // Validation vocabulary
    "https://json-schema.org/draft/2020-12/vocab/validation": [
      "type", "const", "enum", "multipleOf", "maximum", "exclusiveMaximum",
      "minimum", "exclusiveMinimum", "maxLength", "minLength", "pattern",
      "maxItems", "minItems", "uniqueItems", "contains", "maxContains",
      "minContains", "maxProperties", "minProperties", "required",
      "dependentRequired",
    ],
    // Unevaluated vocabulary
    "https://json-schema.org/draft/2020-12/vocab/unevaluated": [
      "unevaluatedItems", "unevaluatedProperties",
    ],
    // Format-annotation vocabulary
    "https://json-schema.org/draft/2020-12/vocab/format-annotation": [
      "format"
    ],
    // Content vocabulary
    "https://json-schema.org/draft/2020-12/vocab/content": [
      "contentMediaType", "contentEncoding", "contentSchema",
    ],
    // Meta-data vocabulary
    "https://json-schema.org/draft/2020-12/vocab/meta-data": [
      "title", "description", "default", "examples", "readOnly", "writeOnly",
      "deprecated",
    ],
  ]

  /// Resolves a `$vocabulary` declaration from a metaschema and returns
  /// the set of enabled keywords. Keywords from vocabularies marked `false`
  /// are excluded.
  private static func enabledKeywords(from metaschema: JSON) -> Set<String>? {
    guard let vocabulary = metaschema["$vocabulary"]?.objectValue else { return nil }
    var enabled = Set<String>()
    for (vocabURL, enabledFlag) in vocabulary {
      guard let flag = enabledFlag.boolValue, flag else { continue }
      if let keywords = vocabularyKeywords[vocabURL] {
        enabled.formUnion(keywords)
      }
    }
    return enabled
  }

  static func detectDraft(from schema: JSON) -> Draft {
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
      errors: &errors, ctx: EvaluationContext()
    )
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
  public func validating(_ document: JSON) -> VerboseResult {
    var errors: [JSONSchemaError] = []
    validateValue(
      document, against: schemaJSON, instancePath: "", schemaPath: "",
      errors: &errors, ctx: EvaluationContext()
    )
    let verboseErrors: [VerboseError]
    if outputMode == .verbose {
      verboseErrors = buildVerboseErrors(from: errors)
    } else {
      verboseErrors = []
    }
    return VerboseResult(
      valid: errors.isEmpty,
      errors: errors,
      verboseErrors: verboseErrors
    )
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
      errors: &errors, ctx: EvaluationContext()
    )
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
  func buildVerboseErrors(from errors: [JSONSchemaError]) -> [VerboseError] {
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

  /// Set of keyword names that are validation-related (not meta-keywords
  /// like `$id`, `$ref`, `$defs`, `$anchor`, `$schema`, `$vocabulary`).
  private static let validationKeywords: Set<String> = [
    "type", "properties", "required", "minimum", "maximum",
    "multipleOf", "pattern", "enum", "const", "minLength", "maxLength",
    "allOf", "anyOf", "oneOf", "not", "if", "minItems", "maxItems",
    "uniqueItems", "contains", "minProperties", "maxProperties",
    "propertyNames", "patternProperties", "additionalProperties",
    "items", "exclusiveMinimum", "exclusiveMaximum",
    "format", "dependencies", "additionalItems",
    "dependentSchemas", "dependentRequired", "prefixItems",
    "unevaluatedItems", "unevaluatedProperties",
    "contentMediaType", "contentEncoding", "contentSchema",
    "minContains", "maxContains",
  ]

  /// Returns a keyword value from the compiled cache if available,
  /// otherwise falls back to looking up from the subschema JSON.
  ///
  /// - Note: Currently unused in this PR. Intended for future use
  ///   where compiled keyword cache can accelerate validation.
  @inline(__always) func keyword(
    _ key: String, from subschema: JSON, at pointer: String
  ) -> JSON? {
    if let cache = compiled?.keywordCache[pointer], let v = cache[key] {
      return v
    }
    return subschema[key]
  }

  func validateValue(
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
          message: "maximum recursion depth exceeded"
        )
      )
      return
    }

    // Determine the resource scope URI for this subschema.
    // If the subschema declares $id, use that; otherwise inherit from parent.
    // Resolve $id against the parent resource URI per RFC 3986.
    // In Draft 7, $ref replaces the entire subschema, so $id is ignored
    // when $ref is present — use the parent's URI for ref resolution.
    let resourceURI: String
    if subschema["$ref"]?.stringValue != nil, draft == .draft7 {
      // Draft 7: $ref replaces the subschema, ignore $id
      resourceURI = ctx.parentResourceURI
    } else if let idVal = subschema["$id"]?.stringValue {
      resourceURI = CompiledSchema.resolveRelativeID(idVal, parentBaseURI: ctx.parentResourceURI)
    } else {
      resourceURI = ctx.currentResourceURI
    }

    if let boolVal = subschema.boolValue {
      if !boolVal {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath, keyword: "false",
            message: "boolean schema false rejects the value"
          )
        )
      }
      return
    }
    guard subschema.isObject else { return }

    // Propagate enabledKeywords from parent context (if not overridden by $schema)
    // Check if this subschema overrides $schema with a metaschema that has $vocabulary.
    // If so, keywords from disabled vocabularies should be ignored.
    let vocabKeywords: Set<String>? = {
      guard let schemaStr = subschema["$schema"]?.stringValue else { return nil }
      let resolvedURI = CompiledSchema.resolveRelativeID(schemaStr, parentBaseURI: resourceURI)
      guard let compiledMeta = remoteCompiled[resolvedURI] else { return nil }
      guard
        let scopeSchema = compiledMeta.resources[""].map(\.scopeSchema)
          ?? compiledMeta.resources.elements.first?.value.scopeSchema
      else { return nil }
      return JSONSchema.enabledKeywords(from: scopeSchema)
    }()
    // Use parent's enabledKeywords if no override, otherwise use vocabKeywords
    let effectiveKeywords = vocabKeywords ?? ctx.enabledKeywords

    // Compute the validation context for this subschema — increment recursion
    // depth, push any $dynamicAnchor onto the scope stack, and update the
    // current resource URI from the subschema's $id (if present).
    // Push the subschema's own $dynamicAnchor (if any).
    var ctxWithAnchor = ctx
    if let dynAnchorStr = subschema["$dynamicAnchor"]?.stringValue,
      compiled != nil
    {
      ctxWithAnchor = ctx.advanced(
        withAnchor: dynAnchorStr, schema: subschema, resourceURI: resourceURI
      )
    } else {
      ctxWithAnchor = ctx.advanced(resourceURI: resourceURI)
    }

    // Also push all $dynamicAnchor from the resource's dynamicAnchors table.
    // This ensures $defs entries with $dynamicAnchor are in scope.
    if compiled != nil,
      let resource = compiled?.resources[resourceURI]
    {
      for (anchorName, anchorSchema) in resource.dynamicAnchors {
        // Skip if already pushed by the subschema check above.
        if subschema["$dynamicAnchor"]?.stringValue != anchorName {
          ctxWithAnchor = ctxWithAnchor.advanced(
            withAnchor: anchorName, schema: anchorSchema, resourceURI: resourceURI
          )
        }
      }
    }

    // Propagate effectiveKeywords to nested subschemas via currentCtx
    let currentCtx = ctxWithAnchor.withEnabledKeywords(effectiveKeywords)

    /// Helper: skips keyword validation if `currentCtx.enabledKeywords` is
    /// non-nil and does not include the given keyword.
    @inline(__always) func keywordEnabled(_ kw: String) -> Bool {
      guard let set = currentCtx.enabledKeywords else { return true }
      return set.contains(kw)
    }

    // Resolve $dynamicRef before $ref — $dynamicRef takes priority per spec.
    if let dynRefStr = subschema["$dynamicRef"]?.stringValue {
      if let resolved = compiled?.resolveDynamicRef(
        dynRefStr, dynamicScope: currentCtx.dynamicScope, currentResourceURI: resourceURI,
        remoteRegistry: remoteCompiled
      ) {
        // For local refs: keep parentResourceURI as the original parent
        // (use advancedViaRef). For remote refs: update parentResourceURI
        // to the remote schema's URI (use advanced).
        let isRemote = compiled?.resources[resolved.resourceURI] == nil
        let resolvedCtx: EvaluationContext
        if isRemote {
          resolvedCtx = currentCtx.advanced(resourceURI: resolved.resourceURI)
        } else {
          resolvedCtx = currentCtx.advancedViaRef(resourceURI: resolved.resourceURI)
        }
        validateValue(
          value, against: resolved.schema, instancePath: instancePath,
          schemaPath: schemaPath + "/$dynamicRef", errors: &errors,
          ctx: resolvedCtx
        )
      } else {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/$dynamicRef",
            keyword: "$dynamicRef",
            message: "unresolvable dynamic reference: '\(dynRefStr)'"
          )
        )
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
      // Use cached resolution if available.
      let cacheKey = resourceURI + "::" + refStr
      let resolved: ResolvedRef?
      if let cache = refCache, let cached = cache.get(cacheKey) {
        resolved = cached
      } else {
        resolved = compiled?.resolveRef(
          refStr, currentResourceURI: resourceURI,
          remoteRegistry: remoteCompiled
        )
        // Store in cache for future use.
        if let r = resolved, let cache = refCache {
          cache.set(cacheKey, to: r)
        }
      }
      guard let resolved = resolved else {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/$ref",
            keyword: "$ref",
            message: "unresolvable reference: '\(refStr)'"
          )
        )
        return
      }
      // Self-reference: $ref resolves back to the same schema (e.g., $ref: "#"
      // at the root).  Skip recursive validation to avoid infinite recursion.
      // But if the subschema has no other keywords (pure cycle), fail.
      if resolved.schema == subschema {
        let hasOtherKeys: Bool
        if case .object(let dict) = subschema.storage {
          hasOtherKeys = dict.keys.contains(where: { $0 != "$ref" })
        } else {
          hasOtherKeys = false
        }
        if !hasOtherKeys {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/$ref",
              keyword: "$ref",
              message: "circular reference: '\(refStr)'"
            )
          )
          return
        }
        // In Draft 7, $ref replaces the subschema, so we return immediately.
        // In Draft 2020-12, sibling keywords are still processed below.
        if draft == .draft7 { return }
        // For Draft 2020-12, skip $ref validation but continue to keywords.
      } else {
        // For local refs: keep parentResourceURI as the original parent
      // so $id resolves correctly (use advancedViaRef).
      // For remote refs: update parentResourceURI to the remote schema's
      // URI since $id should resolve against the remote parent (use advanced).
      let isRemote = compiled?.resources[resolved.resourceURI] == nil
      let resolvedCtx: EvaluationContext
      if isRemote {
        resolvedCtx = currentCtx.advanced(resourceURI: resolved.resourceURI)
      } else {
        resolvedCtx = currentCtx.advancedViaRef(resourceURI: resolved.resourceURI)
      }
      validateValue(
        value, against: resolved.schema, instancePath: instancePath,
        schemaPath: schemaPath + "/$ref", errors: &errors,
        ctx: resolvedCtx
      )
      // In Draft 7, return here — sibling keywords are ignored alongside $ref.
      // In Draft 2020-12, continue processing sibling keywords below.
      if draft == .draft7 { return }
    }
    } // close else block for self-reference check

    // MARK: - Keyword dispatch using pre-computed keyword set

    //
    // Instead of checking every possible keyword for every subschema, we
    // iterate over the keys of the subschema object and dispatch only the
    // keywords that are actually present.  This reduces the overhead of
    // function calls and keyword-enabled checks for absent keywords.

    if case .object(let dict) = subschema.storage {
      // Collect the keyword names from the subschema keys.
      // We skip meta-keywords ($id, $ref, $defs, $anchor, etc.) and
      // only process validation keywords.
      let validationKeywords = Self.validationKeywords

      for (key, _) in dict {
        guard validationKeywords.contains(key) else { continue }
        guard keywordEnabled(key) else { continue }

        switch key {
        // --- Shared keywords (both drafts) ---
        case "type":
          validateType(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "properties":
          validateProperties(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "required":
          validateRequired(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "minimum":
          validateMinimum(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "maximum":
          validateMaximum(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "multipleOf":
          validateMultipleOf(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "pattern":
          validatePattern(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "enum":
          validateEnum(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "const":
          validateConst(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "minLength":
          validateMinLength(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "maxLength":
          validateMaxLength(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "allOf":
          validateAllOf(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "anyOf":
          validateAnyOf(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "oneOf":
          validateOneOf(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "not":
          validateNot(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "if":
          validateIfThenElse(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "minItems":
          validateMinItems(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "maxItems":
          validateMaxItems(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "uniqueItems":
          validateUniqueItems(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "contains":
          validateContains(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "minProperties":
          validateMinProperties(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "maxProperties":
          validateMaxProperties(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "propertyNames":
          validatePropertyNames(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "patternProperties":
          validatePatternProperties(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case "additionalProperties":
          validateAdditionalProperties(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        // --- Keywords with draft-specific dispatch ---
        case "items":
          // In Draft 7, `items` can be either an object (schema) or an array
          // (tuple).  Both validators are needed; each returns early if the
          // value type doesn't match.
          validateItemsSchema(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
          if draft == .draft7 {
            validateItemsTuple(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "exclusiveMinimum":
          // In Draft 7, `exclusiveMinimum` is a boolean modifier, but the
          // test suite also tests numeric `exclusiveMinimum` in Draft 7 mode.
          // Call both validators; the numeric one returns early if the value
          // is not a number, the bool one returns early if `minimum` is absent.
          if draft == .draft7 {
            validateExclusiveMinimum(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
            validateExclusiveMinimumBool(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          } else {
            validateExclusiveMinimum(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "exclusiveMaximum":
          if draft == .draft7 {
            validateExclusiveMaximum(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
            validateExclusiveMaximumBool(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          } else {
            validateExclusiveMaximum(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        // --- Draft 7 keywords ---
        case "format":
          if draft == .draft7 {
            validateFormat(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "dependencies":
          if draft == .draft7 {
            validateDependencies(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "additionalItems":
          if draft == .draft7 {
            validateAdditionalItems(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        // --- Draft 2020-12 keywords ---
        case "dependentSchemas":
          if draft == .draft202012 {
            validateDependentSchemas(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "dependentRequired":
          if draft == .draft202012 {
            validateDependentRequired(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "prefixItems":
          if draft == .draft202012 {
            validatePrefixItems(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "unevaluatedItems":
          if draft == .draft202012 {
            validateUnevaluatedItems(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "unevaluatedProperties":
          if draft == .draft202012 {
            validateUnevaluatedProperties(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "contentMediaType":
          if draft == .draft202012 {
            validateContentMediaType(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "contentEncoding":
          if draft == .draft202012 {
            validateContentEncoding(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "contentSchema":
          if draft == .draft202012 {
            validateContentSchema(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "minContains":
          if draft == .draft202012 {
            validateMinContains(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case "maxContains":
          if draft == .draft202012 {
            validateMaxContains(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        default:
          break
        }
      }
    }
  }

  // MARK: - Schema-aware equality

  /// Compares two JSON values using schema-aware equality semantics.
  /// Integers compare equal to equal floats (`1` == `1.0`). Objects compare
  /// by key-value pairs ignoring key order.
  static func schemaEqual(_ lhs: JSON, _ rhs: JSON) -> Bool {
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
      for (i, elem) in a.enumerated() {
        if !schemaEqual(elem, b[i]) { return false }
      }
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

  // MARK: - Hashable conformance (ignoring runtime caches)

  public func hash(into hasher: inout Hasher) {
    hasher.combine(draft)
    hasher.combine(compiled)
    hasher.combine(formatOptions)
    hasher.combine(outputMode)
    // refCache is excluded — it's a runtime cache, not part of schema identity.
  }

  public static func == (lhs: JSONSchema, rhs: JSONSchema) -> Bool {
    lhs.draft == rhs.draft && lhs.compiled == rhs.compiled && lhs.formatOptions == rhs.formatOptions
      && lhs.outputMode == rhs.outputMode
    // refCache is excluded.
  }
}
