import Foundation
import OrderedCollections

extension JSONSchema {

  // MARK: - Object keywords (shared)

  /// Validates `minProperties` — checks that the object has at least the
  /// specified number of properties.
  func validateMinProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let minVal = subschema[key: .minProperties]?.intValue, value.isObject else { return }
    if value.count < minVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/minProperties",
          keyword: "minProperties",
          message: "object has \(value.count) properties, less than minimum \(minVal)"
        )
      )
    }
  }

  /// Validates `maxProperties` — checks that the object has at most the
  /// specified number of properties.
  func validateMaxProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let maxVal = subschema[key: .maxProperties]?.intValue, value.isObject else { return }
    if value.count > maxVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/maxProperties",
          keyword: "maxProperties",
          message: "object has \(value.count) properties, greater than maximum \(maxVal)"
        )
      )
    }
  }

  /// Validates `propertyNames` — each property key in the object must
  /// validate against the schema (the schema validates the key string).
  func validatePropertyNames(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let pnSchema = subschema[key: .propertyNames], value.isObject else { return }
    guard case .object(let dict) = value.storage else { return }
    for (key, _) in dict {
      var keyErrors: [JSONSchemaError] = []
      let childSchemaPath = schemaPath + "/propertyNames"
      let childInstancePath = instancePath.isEmpty ? "~" + key : instancePath + "/~" + key
      validateValue(
        .string(key), against: pnSchema, instancePath: childInstancePath,
        schemaPath: childSchemaPath, errors: &keyErrors, ctx: ctx
      )
      if let first = keyErrors.first {
        errors.append(
          JSONSchemaError(
            instancePath: childInstancePath, schemaPath: childSchemaPath,
            keyword: "propertyNames",
            message: "property name '\(key)' failed: \(first.message)"
          )
        )
      }
    }
  }

  /// Validates `patternProperties` — property keys matching a regex must
  /// have their value validated against the corresponding schema.
  func validatePatternProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let pp = subschema[key: .patternProperties], pp.isObject, value.isObject else { return }
    guard case .object(let patternDict) = pp.storage, case .object(let dict) = value.storage else {
      return
    }
    for (pattern, schema) in patternDict {
      // Use pre-compiled regex if available, otherwise compile on the fly.
      let regex: NSRegularExpression
      if let compiled = compiled,
        let cached = compiled.precompiledPatterns[pattern]
      {
        regex = cached.regex
      } else if let r = try? NSRegularExpression(pattern: pattern, options: []) {
        regex = r
      } else {
        continue
      }
      for (key, val) in dict {
        let range = NSRange(key.startIndex..<key.endIndex, in: key)
        if regex.firstMatch(in: key, options: [], range: range) != nil {
          validateValue(
            val, against: schema,
            instancePath: instancePath.isEmpty ? key : instancePath + "/" + key,
            schemaPath: schemaPath + "/patternProperties/" + pattern, errors: &errors, ctx: ctx
          )
        }
      }
    }
  }

  // MARK: - Keyword: additionalProperties (shared)

  /// Validates `additionalProperties` — schema for properties not covered
  /// by `properties` or `patternProperties`. Same semantics in both drafts.
  func validateAdditionalProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let additionalProperties = subschema[key: .additionalProperties], value.isObject else {
      return
    }
    guard case .object(let dict) = value.storage else { return }
    let coveredKeys = evaluatedPropertyKeys(
      for: subschema, from: dict, includeAdditionalProperties: false
    )
    for (key, val) in dict {
      if !coveredKeys.contains(key) {
        validateValue(
          val, against: additionalProperties,
          instancePath: instancePath.isEmpty ? key : instancePath + "/" + key,
          schemaPath: schemaPath + "/additionalProperties", errors: &errors, ctx: ctx
        )
      }
    }
  }

  // MARK: - Shared property-key evaluation

  /// Computes the set of property keys in `dict` that are evaluated by
  /// `properties`, `patternProperties`, and optionally `additionalProperties`
  /// and `dependentSchemas` keywords in `subschema`.
  ///
  /// - Parameters:
  ///   - subschema: The schema keyword dictionary.
  ///   - dict: The instance object dictionary to check keys against.
  ///   - includeAdditionalProperties: Whether to also include keys evaluated
  ///     by `additionalProperties` (needed for `unevaluatedProperties`).
  func evaluatedPropertyKeys(
    for subschema: JSON,
    from dict: OrderedDictionary<String, JSON>,
    includeAdditionalProperties: Bool = false
  ) -> Set<String> {
    var keys: Set<String> = []
    if let properties = subschema[key: .properties], properties.isObject {
      guard case .object(let props) = properties.storage else {
        preconditionFailure("properties.isObject was true but storage pattern match failed")
      }
      for (k, _) in props {
        keys.insert(k)
      }
    }
    if let pp = subschema[key: .patternProperties], pp.isObject {
      guard case .object(let patternDict) = pp.storage else {
        preconditionFailure("patternProperties.isObject was true but storage pattern match failed")
      }
      for (pattern, _) in patternDict {
        // Use pre-compiled regex if available, otherwise compile on the fly.
        let regex: NSRegularExpression
        if let compiled = compiled,
          let cached = compiled.precompiledPatterns[pattern]
        {
          regex = cached.regex
        } else {
          regex = try! NSRegularExpression(pattern: pattern, options: [])
        }
        for (key, _) in dict {
          let range = NSRange(key.startIndex..<key.endIndex, in: key)
          if regex.firstMatch(in: key, options: [], range: range) != nil { keys.insert(key) }
        }
      }
    }
    if includeAdditionalProperties, subschema[key: .additionalProperties] != nil {
      for (key, _) in dict {
        keys.insert(key)
      }
    }
    return keys
  }

  /// Recursively computes the set of property keys that a schema (including
  /// its composition keywords) evaluates for the given object data.
  func evaluatedPropertyKeysRecursive(
    for subschema: JSON,
    dict: OrderedDictionary<String, JSON>,
    instancePath: String,
    schemaPath: String,
    ctx: EvaluationContext,
    includeUnevaluatedProperties: Bool = false
  ) -> Set<String> {
    var keys = evaluatedPropertyKeys(for: subschema, from: dict, includeAdditionalProperties: true)

    // Resolve $ref target first — merge evaluated keys from the
    // referenced schema before processing local keywords.
    if let refStr = subschema[key: .dollarRef]?.stringValue {
      if let resolved = compiled?.resolveRef(
        refStr, currentResourceURI: ctx.currentResourceURI,
        remoteRegistry: remoteCompiled
      ) {
        let targetKeys = evaluatedPropertyKeysRecursive(
          for: resolved.schema, dict: dict,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedProperties: true
        )
        keys.formUnion(targetKeys)
      }
    }

    // Resolve $dynamicRef target — merge evaluated keys from the
    // dynamically referenced schema.
    if let dynRefStr = subschema[key: .dollarDynamicRef]?.stringValue {
      if let resolved = compiled?.resolveDynamicRef(
        dynRefStr,
        dynamicScope: ctx.dynamicScope, currentResourceURI: ctx.currentResourceURI,
        remoteRegistry: remoteCompiled
      ) {
        let targetKeys = evaluatedPropertyKeysRecursive(
          for: resolved.schema, dict: dict,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedProperties: true
        )
        keys.formUnion(targetKeys)
      }
    }

    // dependentSchemas: when a triggering key is present, the dependent
    // schema's evaluated properties are added.
    if let depSchemas = subschema[key: .dependentSchemas], depSchemas.isObject {
      guard case .object(let depDict) = depSchemas.storage else { return keys }
      for (depKey, depSchema) in depDict {
        guard dict[depKey] != nil else { continue }
        let depKeys = evaluatedPropertyKeysRecursive(
          for: depSchema, dict: dict,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedProperties: true
        )
        keys.formUnion(depKeys)
      }
    }

    // allOf: union of all subschemas' evaluated keys.
    // Resolve $ref in each subschema before collecting keys.
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
        let subKeys = evaluatedPropertyKeysRecursive(
          for: subSchema, dict: dict,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedProperties: true
        )
        keys.formUnion(subKeys)
      }
    }

    // anyOf: union of matching subschemas' evaluated keys.
    // Resolve $ref in each subschema before collecting keys.
    if let anyOf = subschema[key: .anyOf], anyOf.isArray {
      let objectValue = JSON(dict)
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
          objectValue, against: subSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/anyOf", errors: &subErrors, ctx: ctx
        )
        if subErrors.isEmpty {
          let subKeys = evaluatedPropertyKeysRecursive(
            for: subSchema, dict: dict,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedProperties: true
          )
          keys.formUnion(subKeys)
        }
      }
    }

    // oneOf: union of matching subschemas' evaluated keys.
    // Resolve $ref in each subschema before collecting keys.
    if let oneOf = subschema[key: .oneOf], oneOf.isArray {
      let objectValue = JSON(dict)
      for sub in oneOf {
        let subSchema: JSON
        if let innerRef = sub["$ref"]?.stringValue,
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
          objectValue, against: subSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/oneOf", errors: &subErrors, ctx: ctx
        )
        if subErrors.isEmpty {
          let subKeys = evaluatedPropertyKeysRecursive(
            for: subSchema, dict: dict,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedProperties: true
          )
          keys.formUnion(subKeys)
        }
      }
    }

    // if/then/else: only the matching branch's evaluated keys count.
    // Resolve $ref in if/then/else subschemas before collecting keys.
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
      let objectValue = JSON(dict)
      validateValue(
        objectValue, against: ifSchemaResolved, instancePath: instancePath,
        schemaPath: schemaPath + "/if", errors: &ifErrors, ctx: ctx
      )
      if ifErrors.isEmpty {
        let ifKeys = evaluatedPropertyKeysRecursive(
          for: ifSchemaResolved, dict: dict,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedProperties: true
        )
        keys.formUnion(ifKeys)
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
          let thenKeys = evaluatedPropertyKeysRecursive(
            for: thenSchemaResolved, dict: dict,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedProperties: true
          )
          keys.formUnion(thenKeys)
        }
      } else {
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
          let elseKeys = evaluatedPropertyKeysRecursive(
            for: elseSchemaResolved, dict: dict,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedProperties: true
          )
          keys.formUnion(elseKeys)
        }
      }
    }

    // unevaluatedProperties: when called from composition keyword context,
    // keys validated by unevaluatedProperties are also considered evaluated.
    if includeUnevaluatedProperties, subschema[key: .unevaluatedProperties] != nil {
      for (key, _) in dict {
        if !keys.contains(key) {
          keys.insert(key)
        }
      }
    }

    return keys
  }
}
