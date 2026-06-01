import Foundation
import OrderedCollections

extension JSONSchema {

  // MARK: - Evaluation tracking helpers

  /// Recursively computes the set of item indices that a schema (including
  /// its composition keywords) evaluates for the given array data.
  ///
  /// Examines `prefixItems`, `items`, `contains`, and in-place applicators
  /// (`allOf`, `anyOf`, `oneOf`, `if`/`then`/`else`) to determine which
  /// indices are considered evaluated.
  func evaluatedItemIndices(
    for subschema: JSON,
    data: [JSON],
    instancePath: String,
    schemaPath: String,
    ctx: EvaluationContext,
    includeUnevaluatedItems: Bool = false
  ) -> Set<Int> {
    var indices: Set<Int> = []
    let dataCount = data.count
    // Cache prefixCount to avoid repeated lookups of prefixItems.arrayValue?.count.
    let prefixCount = subschema[key: .prefixItems]?.arrayValue?.count ?? 0

    // Resolve $ref target first — merge evaluated indices from the
    // referenced schema before processing local keywords.
    if let refStr = subschema[key: .dollarRef]?.stringValue,
      let resolved = compiled?.resolveRef(
        refStr, currentResourceURI: ctx.currentResourceURI,
        remoteRegistry: remoteCompiled
      )
    {
      let targetKeys = evaluatedItemIndices(
        for: resolved.schema, data: data,
        instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
        includeUnevaluatedItems: true
      )
      indices.formUnion(targetKeys)
    }

    // Resolve $dynamicRef target — merge evaluated indices from the
    // dynamically referenced schema.
    if let dynRefStr = subschema[key: .dollarDynamicRef]?.stringValue {
      if let resolved = compiled?.resolveDynamicRef(
        dynRefStr,
        dynamicScope: ctx.dynamicScope, currentResourceURI: ctx.currentResourceURI,
        remoteRegistry: remoteCompiled
      ) {
        let targetKeys = evaluatedItemIndices(
          for: resolved.schema, data: data,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedItems: true
        )
        indices.formUnion(targetKeys)
      }
    }

    // prefixItems: indices 0..<count are evaluated
    if let prefixItems = subschema[key: .prefixItems], prefixItems.isArray {
      let count = prefixItems.arrayValue?.count ?? 0
      for i in 0..<min(count, dataCount) {
        indices.insert(i)
      }
    }

    // items: if a schema, all remaining indices are evaluated
    if let items = subschema[key: .items] {
      if items.isObject {
        for i in prefixCount..<dataCount {
          indices.insert(i)
        }
      } else if let boolVal = items.boolValue, boolVal {
        for i in prefixCount..<dataCount {
          indices.insert(i)
        }
      }
    }

    // contains: matching items are evaluated
    if let containsSchema = subschema[key: .contains] {
      for i in 0..<prefixCount {
        indices.insert(i)
      }
      for i in prefixCount..<dataCount {
        var itemErrors: [JSONSchemaError] = []
        validateValue(
          data[i], against: containsSchema,
          instancePath: instancePath.isEmpty ? String(i) : instancePath + "/" + String(i),
          schemaPath: schemaPath + "/contains", errors: &itemErrors, ctx: ctx
        )
        if itemErrors.isEmpty {
          indices.insert(i)
        }
      }
    }

    // allOf: union of all subschemas' evaluated indices.
    // Resolve $ref in each subschema before collecting indices.
    if let allOf = subschema[key: .allOf], allOf.isArray {
      for sub in allOf {
        let subSchema: JSON
        if let innerRef = sub[key: .dollarRef]?.stringValue,
          let resolved = compiled?.resolveRef(
            innerRef, currentResourceURI: ctx.currentResourceURI,
            remoteRegistry: remoteCompiled
          )
        {
          subSchema = resolved.schema
        } else {
          subSchema = sub
        }
        let subIndices = evaluatedItemIndices(
          for: subSchema, data: data,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedItems: true
        )
        indices.formUnion(subIndices)
      }
    }

    // anyOf: union of matching subschemas' evaluated indices.
    // Resolve $ref in each subschema before collecting indices.
    if let anyOf = subschema[key: .anyOf], anyOf.isArray {
      let arrayValue = JSON(data)
      for sub in anyOf {
        let subSchema: JSON
        if let innerRef = sub[key: .dollarRef]?.stringValue,
          let resolved = compiled?.resolveRef(
            innerRef, currentResourceURI: ctx.currentResourceURI,
            remoteRegistry: remoteCompiled
          )
        {
          subSchema = resolved.schema
        } else {
          subSchema = sub
        }
        var subErrors: [JSONSchemaError] = []
        validateValue(
          arrayValue, against: subSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/anyOf", errors: &subErrors, ctx: ctx
        )
        if subErrors.isEmpty {
          let subIndices = evaluatedItemIndices(
            for: subSchema, data: data,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedItems: true
          )
          indices.formUnion(subIndices)
        }
      }
    }

    // oneOf: union of matching subschemas' evaluated indices.
    // Resolve $ref in each subschema before collecting indices.
    if let oneOf = subschema[key: .oneOf], oneOf.isArray {
      let arrayValue = JSON(data)
      for sub in oneOf {
        let subSchema: JSON
        if let innerRef = sub[key: .dollarRef]?.stringValue,
          let resolved = compiled?.resolveRef(
            innerRef, currentResourceURI: ctx.currentResourceURI,
            remoteRegistry: remoteCompiled
          )
        {
          subSchema = resolved.schema
        } else {
          subSchema = sub
        }
        var subErrors: [JSONSchemaError] = []
        validateValue(
          arrayValue, against: subSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/oneOf", errors: &subErrors, ctx: ctx
        )
        if subErrors.isEmpty {
          let subIndices = evaluatedItemIndices(
            for: subSchema, data: data,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedItems: true
          )
          indices.formUnion(subIndices)
        }
      }
    }

    // if/then/else: only the matching branch's evaluated indices count.
    // Resolve $ref in if/then/else subschemas before collecting indices.
    if let ifSchema = subschema[key: .if] {
      let ifSchemaResolved: JSON
      if let innerRef = ifSchema["$ref"]?.stringValue,
        let resolved = compiled?.resolveRef(
          innerRef, currentResourceURI: ctx.currentResourceURI,
          remoteRegistry: remoteCompiled
        )
      {
        ifSchemaResolved = resolved.schema
      } else {
        ifSchemaResolved = ifSchema
      }
      var ifErrors: [JSONSchemaError] = []
      let arrayValue = JSON(data)
      validateValue(
        arrayValue, against: ifSchemaResolved, instancePath: instancePath,
        schemaPath: schemaPath + "/if", errors: &ifErrors, ctx: ctx
      )
      if ifErrors.isEmpty {
        // if matches — take if's indices plus then's indices
        let ifIndices = evaluatedItemIndices(
          for: ifSchemaResolved, data: data,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedItems: true
        )
        indices.formUnion(ifIndices)
        if let thenSchema = subschema[key: .then] {
          let thenSchemaResolved: JSON
          if let innerRef = thenSchema["$ref"]?.stringValue,
            let resolved = compiled?.resolveRef(
              innerRef, currentResourceURI: ctx.currentResourceURI,
              remoteRegistry: remoteCompiled
            )
          {
            thenSchemaResolved = resolved.schema
          } else {
            thenSchemaResolved = thenSchema
          }
          let thenIndices = evaluatedItemIndices(
            for: thenSchemaResolved, data: data,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedItems: true
          )
          indices.formUnion(thenIndices)
        }
      } else {
        // if fails — only else's indices count (if present)
        if let elseSchema = subschema[key: .else] {
          let elseSchemaResolved: JSON
          if let innerRef = elseSchema["$ref"]?.stringValue,
            let resolved = compiled?.resolveRef(
              innerRef, currentResourceURI: ctx.currentResourceURI,
              remoteRegistry: remoteCompiled
            )
          {
            elseSchemaResolved = resolved.schema
          } else {
            elseSchemaResolved = elseSchema
          }
          let elseIndices = evaluatedItemIndices(
            for: elseSchemaResolved, data: data,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedItems: true
          )
          indices.formUnion(elseIndices)
        }
        // No indices from if itself when if fails
      }
    }

    // unevaluatedItems: when called from composition keyword context,
    // items validated by unevaluatedItems are also considered evaluated.
    if includeUnevaluatedItems, subschema[key: .unevaluatedItems] != nil {
      for i in 0..<dataCount {
        if !indices.contains(i) {
          indices.insert(i)
        }
      }
    }

    return indices
  }

  // MARK: - Keyword: unevaluatedItems

  /// Validates `unevaluatedItems` (Draft 2020-12) — schema for items not
  /// evaluated by `prefixItems`, `items`, `contains`, or in-place
  /// applicators (`allOf`, `anyOf`, `oneOf`, `if`/`then`/`else`).
  func validateUnevaluatedItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let unevaluated = subschema[key: .unevaluatedItems], let arr = value.arrayValue else {
      return
    }
    // If items is a schema (not boolean), all items past prefixItems are
    // evaluated — unevaluatedItems doesn't apply.
    if let items = subschema[key: .items], items.isObject { return }
    // Compute the set of indices evaluated by this schema (including
    // composition keywords).
    let evaluated = evaluatedItemIndices(
      for: subschema, data: arr,
      instancePath: instancePath, schemaPath: schemaPath, ctx: ctx
    )
    for (index, item) in arr.enumerated() {
      if evaluated.contains(index) { continue }
      validateValue(
        item, against: unevaluated,
        instancePath: instancePath.isEmpty ? String(index) : instancePath + "/" + String(index),
        schemaPath: schemaPath + "/unevaluatedItems", errors: &errors, ctx: ctx
      )
    }
  }

  // MARK: - Keyword: unevaluatedProperties

  /// Validates `unevaluatedProperties` (Draft 2020-12) — schema for
  /// properties not evaluated by `properties`, `patternProperties`,
  /// `additionalProperties`, or `dependentSchemas`.
  ///
  /// - Todo: In-place applicators (`allOf`, `anyOf`, `oneOf`, `if`/`then`/`else`)
  ///   can also evaluate properties — their evaluated keys should be tracked.
  func validateUnevaluatedProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let unevaluated = subschema[key: .unevaluatedProperties], value.isObject else { return }
    guard case .object(let dict) = value.storage else { return }
    let evaluatedKeys = evaluatedPropertyKeysRecursive(
      for: subschema, dict: dict,
      instancePath: instancePath, schemaPath: schemaPath, ctx: ctx
    )
    for (key, val) in dict {
      if !evaluatedKeys.contains(key) {
        validateValue(
          val, against: unevaluated,
          instancePath: instancePath.isEmpty ? key : instancePath + "/" + key,
          schemaPath: schemaPath + "/unevaluatedProperties", errors: &errors, ctx: ctx
        )
      }
    }
  }

  // MARK: - Keyword: contentMediaType (annotation — no-op)

  /// Validates the `contentMediaType` keyword (Draft 2020-12 annotation).
  /// In Draft 2020-12, `contentMediaType` is a pure annotation keyword and
  /// does not produce validation errors. In Draft 7, it is also treated as
  /// an annotation (non-assertion).
  ///
  /// This validator is a no-op — it exists for schema completeness and future
  /// use if content-aware validation is added.
  func validateContentMediaType(
    _: JSON, subschema _: JSON, instancePath _: String, schemaPath _: String,
    errors _: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    // contentMediaType is an annotation — no validation errors produced
  }

  // MARK: - Keyword: contentEncoding (annotation — no-op)

  /// Validates the `contentEncoding` keyword (Draft 2020-12 annotation).
  /// In Draft 2020-12, `contentEncoding` is a pure annotation keyword and
  /// does not produce validation errors. In Draft 7, it is also treated as
  /// an annotation (non-assertion).
  ///
  /// This validator is a no-op — it exists for schema completeness and future
  /// use if content-aware validation is added.
  func validateContentEncoding(
    _: JSON, subschema _: JSON, instancePath _: String, schemaPath _: String,
    errors _: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    // contentEncoding is an annotation — no validation errors produced
  }

  // MARK: - Keyword: contentSchema

  /// Validates the `contentSchema` keyword (Draft 2020-12) — validates the
  /// decoded content of a string value against the given schema.
  ///
  /// If `contentEncoding` is `"base64"` and the value is a string, the
  /// content is base64-decoded and then parsed as JSON before validation.
  /// If no encoding is specified, the raw string is parsed as JSON.
  ///
  /// Non-string values are skipped. If the decoded content cannot be parsed
  /// as JSON, a validation error is produced.
  ///
  /// Per Draft 2020-12, `contentSchema` is an **annotation** keyword — it
  /// should NOT produce validation errors.  This implementation is a no-op.
  /// To enable content-aware validation, override this behavior.
  func validateContentSchema(
    _: JSON, subschema _: JSON, instancePath _: String, schemaPath _: String,
    errors _: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    // contentSchema is an annotation keyword per Draft 2020-12.
    // It does NOT produce validation errors.
  }

  // MARK: - Keyword: minContains / maxContains

  /// Validates `minContains` (Draft 2020-12) — the array must contain at
  /// least `minContains` items matching the `contains` subschema.
  func validateMinContains(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let minContains = subschema[key: .minContains]?.intValue,
      subschema[key: .contains] != nil,
      let arr = value.arrayValue
    else { return }
    let containsSchema = subschema[key: .contains]!
    var matchCount = 0
    for item in arr {
      var itemErrors: [JSONSchemaError] = []
      validateValue(
        item, against: containsSchema, instancePath: instancePath,
        schemaPath: schemaPath + "/contains", errors: &itemErrors, ctx: ctx
      )
      if itemErrors.isEmpty { matchCount += 1 }
    }
    if matchCount < minContains {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/minContains",
          keyword: .minContains,
          message:
            "array contains \(matchCount) items matching the subschema, minimum \(minContains)"
        )
      )
    }
  }

  /// Validates `maxContains` (Draft 2020-12) — the array must contain at
  /// most `maxContains` items matching the `contains` subschema.
  func validateMaxContains(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let maxContains = subschema[key: .maxContains]?.intValue,
      subschema[key: .contains] != nil,
      let arr = value.arrayValue
    else { return }
    let containsSchema = subschema[key: .contains]!
    var matchCount = 0
    for item in arr {
      var itemErrors: [JSONSchemaError] = []
      validateValue(
        item, against: containsSchema, instancePath: instancePath,
        schemaPath: schemaPath + "/contains", errors: &itemErrors, ctx: ctx
      )
      if itemErrors.isEmpty { matchCount += 1 }
    }
    if matchCount > maxContains {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/maxContains",
          keyword: .maxContains,
          message:
            "array contains \(matchCount) items matching the subschema, maximum \(maxContains)"
        )
      )
    }
  }
}
