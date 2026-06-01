import Foundation
import OrderedCollections

extension JSONSchema {

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
      let parentIndex = groupErrors.firstIndex(where: { $0.keyword.rawValue == key }) ?? 0
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

  /// Maximum recursion depth for schema validation.
  /// Prevents stack overflow from deeply nested or circular schemas.
  /// Conservative; revisit if OpenAPI/AsyncAPI corpora hit the wall.
  private static let maxRecursionDepth = 20

  /// Set of keyword names that are validation-related (not meta-keywords
  /// like `$id`, `$ref`, `$defs`, `$anchor`, `$schema`, `$vocabulary`).
  package static let validationKeywords: Set<JSONSchemaKeyword> = [
    .type, .properties, .required, .minimum, .maximum,
    .multipleOf, .pattern, .enum, .const, .minLength, .maxLength,
    .allOf, .anyOf, .oneOf, .not, .if, .minItems, .maxItems,
    .uniqueItems, .contains, .minProperties, .maxProperties,
    .propertyNames, .patternProperties, .additionalProperties,
    .items, .exclusiveMinimum, .exclusiveMaximum,
    .format, .dependencies, .additionalItems,
    .dependentSchemas, .dependentRequired, .prefixItems,
    .unevaluatedItems, .unevaluatedProperties,
    .contentMediaType, .contentEncoding, .contentSchema,
    .minContains, .maxContains,
  ]

  /// Returns a keyword value from the compiled cache if available,
  /// otherwise falls back to looking up from the subschema JSON.
  @inline(__always) func keyword(
    _ key: JSONSchemaKeyword, from subschema: JSON, at pointer: String
  ) -> JSON? {
    if let cache = compiled?.keywordCache[pointer], let v = cache[key] {
      return v
    }
    return subschema[key: key]
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
          keyword: .schemaError,
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
    if subschema[key: .dollarRef]?.stringValue != nil, draft == .draft7 {
      // Draft 7: $ref replaces the subschema, ignore $id
      resourceURI = ctx.parentResourceURI
    } else if let idVal = subschema[key: .dollarId]?.stringValue {
      resourceURI = CompiledSchema.resolveRelativeID(idVal, parentBaseURI: ctx.parentResourceURI)
    } else {
      resourceURI = ctx.currentResourceURI
    }

    if let boolVal = subschema.boolValue {
      if !boolVal {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath, keyword: .falseSchema,
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
    let vocabKeywords: Set<JSONSchemaKeyword>? = {
      guard let schemaStr = subschema[key: .dollarSchema]?.stringValue else { return nil }
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
    if let dynAnchorStr = subschema[key: .dollarDynamicAnchor]?.stringValue,
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
        if subschema[key: .dollarDynamicAnchor]?.stringValue != anchorName {
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
    @inline(__always) func keywordEnabled(_ kw: JSONSchemaKeyword) -> Bool {
      guard let set = currentCtx.enabledKeywords else { return true }
      return set.contains(kw)
    }

    // Resolve $dynamicRef before $ref — $dynamicRef takes priority per spec.
    if let dynRefStr = subschema[key: .dollarDynamicRef]?.stringValue {
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
            keyword: .dollarDynamicRef,
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
    if let refStr = subschema[key: .dollarRef]?.stringValue {
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
            keyword: .dollarRef,
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
          let refKey = JSONSchemaKeyword.dollarRef.rawValue
          hasOtherKeys = dict.keys.contains { $0 != refKey }
        } else {
          hasOtherKeys = false
        }
        if !hasOtherKeys {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/$ref",
              keyword: .dollarRef,
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
    }  // close else block for self-reference check

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
        // Convert the string key to our enum for typed comparisons.
        // Unknown keywords (not in JSONSchemaKeyword) fall through to default.
        guard let kw = JSONSchemaKeyword(rawValue: key) else { continue }
        guard validationKeywords.contains(kw) else { continue }
        guard keywordEnabled(kw) else { continue }

        switch kw {
        // --- Shared keywords (both drafts) ---
        case .type:
          validateType(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .properties:
          validateProperties(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .required:
          validateRequired(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .minimum:
          validateMinimum(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .maximum:
          validateMaximum(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .multipleOf:
          validateMultipleOf(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .pattern:
          validatePattern(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .enum:
          validateEnum(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .const:
          validateConst(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .minLength:
          validateMinLength(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .maxLength:
          validateMaxLength(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .allOf:
          validateAllOf(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .anyOf:
          validateAnyOf(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .oneOf:
          validateOneOf(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .not:
          validateNot(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .if:
          validateIfThenElse(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .minItems:
          validateMinItems(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .maxItems:
          validateMaxItems(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .uniqueItems:
          validateUniqueItems(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .contains:
          validateContains(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .minProperties:
          validateMinProperties(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .maxProperties:
          validateMaxProperties(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .propertyNames:
          validatePropertyNames(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .patternProperties:
          validatePatternProperties(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        case .additionalProperties:
          validateAdditionalProperties(
            value, subschema: subschema, instancePath: instancePath,
            schemaPath: schemaPath, errors: &errors, ctx: currentCtx
          )
        // --- Keywords with draft-specific dispatch ---
        case .items:
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
        case .exclusiveMinimum:
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
        case .exclusiveMaximum:
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
        case .format:
          if draft == .draft7 {
            validateFormat(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case .dependencies:
          if draft == .draft7 {
            validateDependencies(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case .additionalItems:
          if draft == .draft7 {
            validateAdditionalItems(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        // --- Draft 2020-12 keywords ---
        case .dependentSchemas:
          if draft == .draft202012 {
            validateDependentSchemas(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case .dependentRequired:
          if draft == .draft202012 {
            validateDependentRequired(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case .prefixItems:
          if draft == .draft202012 {
            validatePrefixItems(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case .unevaluatedItems:
          if draft == .draft202012 {
            validateUnevaluatedItems(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case .unevaluatedProperties:
          if draft == .draft202012 {
            validateUnevaluatedProperties(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case .contentMediaType:
          if draft == .draft202012 {
            validateContentMediaType(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case .contentEncoding:
          if draft == .draft202012 {
            validateContentEncoding(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case .contentSchema:
          if draft == .draft202012 {
            validateContentSchema(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case .minContains:
          if draft == .draft202012 {
            validateMinContains(
              value, subschema: subschema, instancePath: instancePath,
              schemaPath: schemaPath, errors: &errors, ctx: currentCtx
            )
          }
        case .maxContains:
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
}
