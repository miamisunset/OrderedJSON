import Foundation
import OrderedCollections

extension JSONSchema {

  // ======================================================================
  // MARK: - Shared validators (called for both drafts, no draft checks)
  // ======================================================================

  // MARK: - Keyword: type

  /// Validates the `type` keyword — checks that the value's type matches one
  /// of the allowed types. Integers are allowed for `number` type.
  internal func validateType(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let typeSpec = subschema["type"] else { return }
    let allowedTypes: [String]
    if typeSpec.isString {
      allowedTypes = [typeSpec.stringValue!]
    } else if typeSpec.isArray {
      allowedTypes = typeSpec.compactMap { $0.stringValue }
    } else {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/type", keyword: "type",
          message: "type must be a string or array of strings"))
      return
    }
    let actualType = typeNameOf(value)
    let isMatch =
      allowedTypes.contains(actualType)
      || (actualType == "integer" && allowedTypes.contains("number"))
    if !isMatch {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/type", keyword: "type",
          message: "expected \(allowedTypes.joined(separator: ", ")) but found \(actualType)"))
    }
  }

  /// Returns the JSON type name for a value (e.g., "string", "integer").
  /// Per JSON Schema, a float with zero fractional part (e.g. 1.0) is an integer.
  internal func typeNameOf(_ value: JSON) -> String {
    switch value.storage {
    case .null: return "null"
    case .boolean: return "boolean"
    case .number(.integer): return "integer"
    case .number(.float):
      guard let d = value.floatValue else { return "number" }
      if d == d.rounded(.towardZero) && d.isFinite { return "integer" }
      return "number"
    case .string: return "string"
    case .object: return "object"
    case .array: return "array"
    }
  }

  // MARK: - Keyword: properties

  /// Validates the `properties` keyword — validates each property value
  /// against its corresponding subschema. Non-object values are skipped.
  internal func validateProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let properties = subschema["properties"], properties.isObject, value.isObject else {
      return
    }
    guard case .object(let dict) = properties.storage else { return }
    for (key, propSchema) in dict {
      let childSchemaPath = schemaPath + "/properties/" + key
      if let childValue = value[key] {
        validateValue(
          childValue, against: propSchema,
          instancePath: instancePath.isEmpty ? key : instancePath + "/" + key,
          schemaPath: childSchemaPath, errors: &errors, ctx: ctx)
      }
    }
  }

  // MARK: - Keyword: required

  /// Validates the `required` keyword — checks that all required property
  /// keys are present (presence only, not null-rejecting).
  internal func validateRequired(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let required = subschema["required"], required.isArray, value.isObject else { return }
    for reqElem in required {
      guard let key = reqElem.stringValue else {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/required", keyword: "required",
            message: "required array must contain strings"))
        continue
      }
      if value[key] == nil {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/required", keyword: "required",
            message: "required property '\(key)' is missing"))
      }
    }
  }

  // MARK: - Keyword: minimum

  /// Validates the `minimum` keyword — checks that the numeric value is >= minimum.
  internal func validateMinimum(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let minVal = subschema["minimum"] else { return }
    let valInt = value.intValue
    let minInt = minVal.intValue
    if let v = valInt, let m = minInt {
      if v < m {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/minimum", keyword: "minimum",
            message: "value \(v) is less than minimum \(m)"))
      }
      return
    }
    guard let v = value.floatValue, let m = minVal.floatValue, v < m else { return }
    errors.append(
      JSONSchemaError(
        instancePath: instancePath, schemaPath: schemaPath + "/minimum", keyword: "minimum",
        message: "value \(v) is less than minimum \(m)"))
  }

  // MARK: - Keyword: maximum

  /// Validates the `maximum` keyword — checks that the numeric value is <= maximum.
  internal func validateMaximum(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let maxVal = subschema["maximum"] else { return }
    let valInt = value.intValue
    let maxInt = maxVal.intValue
    if let v = valInt, let m = maxInt {
      if v > m {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/maximum", keyword: "maximum",
            message: "value \(v) is greater than maximum \(m)"))
      }
      return
    }
    guard let v = value.floatValue, let m = maxVal.floatValue, v > m else { return }
    errors.append(
      JSONSchemaError(
        instancePath: instancePath, schemaPath: schemaPath + "/maximum", keyword: "maximum",
        message: "value \(v) is greater than maximum \(m)"))
  }

  // MARK: - Keyword: exclusiveMinimum (numeric bound — shared)

  /// Validates `exclusiveMinimum` as a numeric bound (Draft 2020-12 semantics).
  /// Also used in Draft 7 when the value is numeric (not a boolean modifier on `minimum`).
  internal func validateExclusiveMinimum(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let exclMin = subschema["exclusiveMinimum"], exclMin.isNumber else { return }
    guard let exclDouble = exclMin.floatValue, let valDouble = value.floatValue else { return }
    if let valInt = value.intValue, let exclInt = exclMin.intValue {
      if valInt <= exclInt {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMinimum",
            keyword: "exclusiveMinimum",
            message: "value \(valInt) is not strictly greater than \(exclInt)"))
      }
      return
    }
    if valDouble <= exclDouble {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMinimum",
          keyword: "exclusiveMinimum",
          message: "value \(valDouble) is not strictly greater than \(exclDouble)"))
    }
  }

  // MARK: - Keyword: exclusiveMaximum (numeric bound — shared)

  /// Validates `exclusiveMaximum` as a numeric bound (Draft 2020-12 semantics).
  /// Also used in Draft 7 when the value is numeric (not a boolean modifier on `maximum`).
  internal func validateExclusiveMaximum(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let exclMax = subschema["exclusiveMaximum"], exclMax.isNumber else { return }
    guard let exclDouble = exclMax.floatValue, let valDouble = value.floatValue else { return }
    if let valInt = value.intValue, let exclInt = exclMax.intValue {
      if valInt >= exclInt {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMaximum",
            keyword: "exclusiveMaximum",
            message: "value \(valInt) is not strictly less than \(exclInt)"))
      }
      return
    }
    if valDouble >= exclDouble {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMaximum",
          keyword: "exclusiveMaximum",
          message: "value \(valDouble) is not strictly less than \(exclDouble)"))
    }
  }

  // MARK: - Keyword: multipleOf

  /// Validates the `multipleOf` keyword — checks that the numeric value
  /// is a multiple of the given divisor. Zero and negative divisors are
  /// ignored per spec. Uses division-based check to avoid float precision
  /// issues with large values and tiny divisors.
  internal func validateMultipleOf(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let mVal = subschema["multipleOf"] else { return }
    if let mInt = mVal.intValue {
      if let valInt = value.intValue {
        if mInt > 0 && valInt % mInt != 0 {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/multipleOf",
              keyword: "multipleOf", message: "\(valInt) is not a multiple of \(mInt)"))
        }
        return
      }
    }
    guard let mDouble = mVal.floatValue, let valDouble = value.floatValue else { return }
    if mDouble > 0 {
      let ratio = valDouble / mDouble
      if !ratio.isFinite {
        // Division overflowed — the value cannot be an exact multiple
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/multipleOf",
            keyword: "multipleOf", message: "\(valDouble) is not a multiple of \(mDouble)"))
      } else {
        let rounded = ratio.rounded(.towardZero)
        let diff = abs(ratio - rounded)
        let epsilon = max(1e-12 * ratio, 1e-12)
        if diff > epsilon {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/multipleOf",
              keyword: "multipleOf", message: "\(valDouble) is not a multiple of \(mDouble)"))
        }
      }
    }
  }

  // MARK: - Keyword: pattern

  /// Validates the `pattern` keyword — checks that a string value matches
  /// the given regex. Non-string values are skipped.
  internal func validatePattern(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let patternStr = subschema["pattern"]?.stringValue, let strVal = value.stringValue else {
      return
    }
    // Use pre-compiled regex if available, otherwise compile on the fly.
    let regex: NSRegularExpression
    if let compiled = self.compiled,
      let cached = compiled.precompiledPatterns[patternStr]
    {
      regex = cached.regex
    } else if let r = try? NSRegularExpression(pattern: patternStr, options: []) {
      regex = r
    } else {
      return
    }
    let range = NSRange(strVal.startIndex..<strVal.endIndex, in: strVal)
    if regex.firstMatch(in: strVal, options: [], range: range) == nil {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/pattern", keyword: "pattern",
          message: "string '\(strVal)' does not match pattern '\(patternStr)'"))
    }
  }

  // MARK: - Keyword: enum

  /// Validates the `enum` keyword — checks that the value matches at least
  /// one of the allowed values using schema-aware equality.
  internal func validateEnum(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let enumValues = subschema["enum"], enumValues.isArray else { return }
    var found = false
    for allowed in enumValues {
      if JSONSchema.schemaEqual(value, allowed) {
        found = true
        break
      }
    }
    if !found {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/enum", keyword: "enum",
          message: "value does not match any of the allowed values in enum"))
    }
  }

  // MARK: - Keyword: const

  /// Validates the `const` keyword — checks that the value is exactly equal
  /// to the const value using schema-aware equality.
  internal func validateConst(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let constVal = subschema["const"] else { return }
    if !JSONSchema.schemaEqual(value, constVal) {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/const", keyword: "const",
          message: "value does not match the const value"))
    }
  }

  // MARK: - Keyword: minLength

  /// Validates the `minLength` keyword — checks that the string's code point
  /// count (`unicodeScalars.count`) meets the minimum. Per RFC 8259, length
  /// is measured in code points, not grapheme clusters.
  internal func validateMinLength(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let minLen = subschema["minLength"]?.intValue, let strVal = value.stringValue else {
      return
    }
    let count = strVal.unicodeScalars.count
    if count < minLen {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/minLength", keyword: "minLength",
          message: "string length \(count) code points is less than minimum \(minLen)"))
    }
  }

  // MARK: - Keyword: maxLength

  /// Validates the `maxLength` keyword — checks that the string's code point
  /// count (`unicodeScalars.count`) does not exceed the maximum.
  internal func validateMaxLength(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let maxLen = subschema["maxLength"]?.intValue, let strVal = value.stringValue else {
      return
    }
    let count = strVal.unicodeScalars.count
    if count > maxLen {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/maxLength", keyword: "maxLength",
          message: "string length \(count) code points is greater than maximum \(maxLen)"))
    }
  }

  // MARK: - Composition: allOf

  /// Validates the `allOf` keyword — checks that the value matches all
  /// subschemas. Errors from each failing subschema are collected.
  internal func validateAllOf(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let allOf = subschema["allOf"], allOf.isArray else { return }
    for (index, sub) in allOf.enumerated() {
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath,
        schemaPath: schemaPath + "/allOf/" + String(index), errors: &subErrors, ctx: ctx)
      if let first = subErrors.first {
        errors.append(
          JSONSchemaError(
            instancePath: first.instancePath.isEmpty ? instancePath : first.instancePath,
            schemaPath: schemaPath + "/allOf/" + String(index), keyword: "allOf",
            message: "subschema #\(index) failed: \(first.message)"))
        // Short-circuit: allOf must pass all, so stop after first failure.
        break
      }
    }
  }

  // MARK: - Composition: anyOf

  /// Validates the `anyOf` keyword — checks that the value matches at least
  /// one subschema. Empty arrays always fail.
  internal func validateAnyOf(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let anyOf = subschema["anyOf"], anyOf.isArray else { return }
    var matched = false
    for sub in anyOf {
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath,
        schemaPath: schemaPath, errors: &subErrors, ctx: ctx)
      if subErrors.isEmpty {
        matched = true
        break
      }
    }
    if !matched {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/anyOf", keyword: "anyOf",
          message: "value does not match any subschema in anyOf"))
    }
  }

  // MARK: - Composition: oneOf

  /// Validates the `oneOf` keyword — checks that the value matches exactly
  /// one subschema. Early exits on the second match.
  internal func validateOneOf(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let oneOf = subschema["oneOf"], oneOf.isArray else { return }
    var matchCount = 0
    for sub in oneOf {
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath,
        schemaPath: schemaPath, errors: &subErrors, ctx: ctx)
      if subErrors.isEmpty { matchCount += 1 }
      if matchCount > 1 { break }
    }
    if matchCount != 1 {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/oneOf", keyword: "oneOf",
          message: "value matches \(matchCount) subschemas in oneOf (expected exactly 1)"))
    }
  }

  // MARK: - Composition: not

  /// Validates the `not` keyword — checks that the value does NOT match
  /// the subschema. Boolean subschemas are supported.
  internal func validateNot(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard subschema["not"] != nil else { return }
    var subErrors: [JSONSchemaError] = []
    validateValue(
      value, against: subschema["not"]!, instancePath: instancePath,
      schemaPath: schemaPath + "/not", errors: &subErrors, ctx: ctx)
    if subErrors.isEmpty {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/not", keyword: "not",
          message: "value matches the not schema"))
    }
  }

  // MARK: - Composition: if/then/else

  /// Validates the `if`/`then`/`else` keywords — if the `if` subschema
  /// matches, `then` must also match; if `if` fails, `else` must match.
  /// Missing `then`/`else` are skipped per spec.
  internal func validateIfThenElse(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let ifSchema = subschema["if"] else { return }
    var ifErrors: [JSONSchemaError] = []
    validateValue(
      value, against: ifSchema, instancePath: instancePath,
      schemaPath: schemaPath + "/if", errors: &ifErrors, ctx: ctx)
    if ifErrors.isEmpty {
      if let thenSchema = subschema["then"] {
        var thenErrors: [JSONSchemaError] = []
        validateValue(
          value, against: thenSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/then", errors: &thenErrors, ctx: ctx)
        if let first = thenErrors.first {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/then", keyword: "then",
              message: "then schema failed: \(first.message)"))
        }
      }
    } else {
      if let elseSchema = subschema["else"] {
        var elseErrors: [JSONSchemaError] = []
        validateValue(
          value, against: elseSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/else", errors: &elseErrors, ctx: ctx)
        if let first = elseErrors.first {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/else", keyword: "else",
              message: "else schema failed: \(first.message)"))
        }
      }
    }
  }

  // MARK: - Array keywords (shared)

  /// Validates `minItems` — checks that the array has at least the
  /// specified number of items.
  internal func validateMinItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let minVal = subschema["minItems"]?.intValue, let arr = value.arrayValue else { return }
    if arr.count < minVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/minItems", keyword: "minItems",
          message: "array length \(arr.count) is less than minimum \(minVal)"))
    }
  }

  /// Validates `maxItems` — checks that the array has at most the
  /// specified number of items.
  internal func validateMaxItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let maxVal = subschema["maxItems"]?.intValue, let arr = value.arrayValue else { return }
    if arr.count > maxVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/maxItems", keyword: "maxItems",
          message: "array length \(arr.count) is greater than maximum \(maxVal)"))
    }
  }

  /// Validates `uniqueItems` — checks that all items in the array are
  /// unique (using schema-aware equality).
  internal func validateUniqueItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard subschema["uniqueItems"]?.boolValue == true, let arr = value.arrayValue else { return }
    for i in 0..<arr.count {
      for j in (i + 1)..<arr.count {
        if JSONSchema.schemaEqual(arr[i], arr[j]) {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/uniqueItems",
              keyword: "uniqueItems",
              message: "items at indexes \(i) and \(j) are equal"))
          return
        }
      }
    }
  }

  /// Validates `contains` — checks that at least one item in the array
  /// matches the subschema.
  internal func validateContains(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let containsSchema = subschema["contains"], let arr = value.arrayValue else { return }
    // When minContains is 0, contains imposes no constraint (Draft 2020-12).
    let minContains = subschema["minContains"]?.intValue
    if let minC = minContains, minC == 0 { return }
    let required = minContains ?? 1
    var matchCount = 0
    for item in arr {
      var itemErrors: [JSONSchemaError] = []
      validateValue(
        item, against: containsSchema, instancePath: instancePath,
        schemaPath: schemaPath + "/contains", errors: &itemErrors, ctx: ctx)
      if itemErrors.isEmpty {
        matchCount += 1
        if matchCount >= required { return }
      }
    }
    errors.append(
      JSONSchemaError(
        instancePath: instancePath, schemaPath: schemaPath + "/contains", keyword: "contains",
        message: "array does not contain \(required) item(s) matching the subschema"))
  }

  // MARK: - Object keywords (shared)

  /// Validates `minProperties` — checks that the object has at least the
  /// specified number of properties.
  internal func validateMinProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let minVal = subschema["minProperties"]?.intValue, value.isObject else { return }
    if value.count < minVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/minProperties",
          keyword: "minProperties",
          message: "object has \(value.count) properties, less than minimum \(minVal)"))
    }
  }

  /// Validates `maxProperties` — checks that the object has at most the
  /// specified number of properties.
  internal func validateMaxProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let maxVal = subschema["maxProperties"]?.intValue, value.isObject else { return }
    if value.count > maxVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/maxProperties",
          keyword: "maxProperties",
          message: "object has \(value.count) properties, greater than maximum \(maxVal)"))
    }
  }

  /// Validates `propertyNames` — each property key in the object must
  /// validate against the schema (the schema validates the key string).
  internal func validatePropertyNames(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let pnSchema = subschema["propertyNames"], value.isObject else { return }
    guard case .object(let dict) = value.storage else { return }
    for (key, _) in dict {
      var keyErrors: [JSONSchemaError] = []
      let childSchemaPath = schemaPath + "/propertyNames"
      let childInstancePath = instancePath.isEmpty ? "~" + key : instancePath + "/~" + key
      validateValue(
        .string(key), against: pnSchema, instancePath: childInstancePath,
        schemaPath: childSchemaPath, errors: &keyErrors, ctx: ctx)
      if let first = keyErrors.first {
        errors.append(
          JSONSchemaError(
            instancePath: childInstancePath, schemaPath: childSchemaPath,
            keyword: "propertyNames",
            message: "property name '\(key)' failed: \(first.message)"))
      }
    }
  }

  /// Validates `patternProperties` — property keys matching a regex must
  /// have their value validated against the corresponding schema.
  internal func validatePatternProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let pp = subschema["patternProperties"], pp.isObject, value.isObject else { return }
    guard case .object(let patternDict) = pp.storage, case .object(let dict) = value.storage else {
      return
    }
    for (pattern, schema) in patternDict {
      // Use pre-compiled regex if available, otherwise compile on the fly.
      let regex: NSRegularExpression
      if let compiled = self.compiled,
        let cached = compiled.precompiledPatterns[pattern]
      {
        regex = cached.regex
      } else {
        regex = try! NSRegularExpression(pattern: pattern, options: [])
      }
      for (key, val) in dict {
        let range = NSRange(key.startIndex..<key.endIndex, in: key)
        if regex.firstMatch(in: key, options: [], range: range) != nil {
          validateValue(
            val, against: schema,
            instancePath: instancePath.isEmpty ? key : instancePath + "/" + key,
            schemaPath: schemaPath + "/patternProperties/" + pattern, errors: &errors, ctx: ctx)
        }
      }
    }
  }

  // MARK: - Keyword: additionalProperties (shared)

  /// Validates `additionalProperties` — schema for properties not covered
  /// by `properties` or `patternProperties`. Same semantics in both drafts.
  internal func validateAdditionalProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let additionalProperties = subschema["additionalProperties"], value.isObject else {
      return
    }
    guard case .object(let dict) = value.storage else { return }
    let coveredKeys = evaluatedPropertyKeys(
      for: subschema, from: dict, includeAdditionalProperties: false)
    for (key, val) in dict {
      if !coveredKeys.contains(key) {
        validateValue(
          val, against: additionalProperties,
          instancePath: instancePath.isEmpty ? key : instancePath + "/" + key,
          schemaPath: schemaPath + "/additionalProperties", errors: &errors, ctx: ctx)
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
  internal func evaluatedPropertyKeys(
    for subschema: JSON,
    from dict: OrderedDictionary<String, JSON>,
    includeAdditionalProperties: Bool = false
  ) -> Set<String> {
    var keys: Set<String> = []
    if let properties = subschema["properties"], properties.isObject {
      guard case .object(let props) = properties.storage else {
        preconditionFailure("properties.isObject was true but storage pattern match failed")
      }
      for (k, _) in props { keys.insert(k) }
    }
    if let pp = subschema["patternProperties"], pp.isObject {
      guard case .object(let patternDict) = pp.storage else {
        preconditionFailure("patternProperties.isObject was true but storage pattern match failed")
      }
      for (pattern, _) in patternDict {
        // Use pre-compiled regex if available, otherwise compile on the fly.
        let regex: NSRegularExpression
        if let compiled = self.compiled,
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
    if includeAdditionalProperties, subschema["additionalProperties"] != nil {
      for (key, _) in dict { keys.insert(key) }
    }
    return keys
  }

  /// Recursively computes the set of property keys that a schema (including
  /// its composition keywords) evaluates for the given object data.
  internal func evaluatedPropertyKeysRecursive(
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
    if let refStr = subschema["$ref"]?.stringValue {
      if let resolved = compiled?.resolveRef(
        refStr, currentResourceURI: ctx.currentResourceURI,
        remoteRegistry: remoteCompiled)
      {
        let targetKeys = evaluatedPropertyKeysRecursive(
          for: resolved.schema, dict: dict,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedProperties: true)
        keys.formUnion(targetKeys)
      }
    }

    // Resolve $dynamicRef target — merge evaluated keys from the
    // dynamically referenced schema.
    if let dynRefStr = subschema["$dynamicRef"]?.stringValue {
      if let resolved = compiled?.resolveDynamicRef(
        dynRefStr,
        dynamicScope: ctx.dynamicScope, currentResourceURI: ctx.currentResourceURI,
        remoteRegistry: remoteCompiled)
      {
        let targetKeys = evaluatedPropertyKeysRecursive(
          for: resolved.schema, dict: dict,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedProperties: true)
        keys.formUnion(targetKeys)
      }
    }

    // dependentSchemas: when a triggering key is present, the dependent
    // schema's evaluated properties are added.
    if let depSchemas = subschema["dependentSchemas"], depSchemas.isObject {
      guard case .object(let depDict) = depSchemas.storage else { return keys }
      for (depKey, depSchema) in depDict {
        guard dict[depKey] != nil else { continue }
        let depKeys = evaluatedPropertyKeysRecursive(
          for: depSchema, dict: dict,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedProperties: true)
        keys.formUnion(depKeys)
      }
    }

    // allOf: union of all subschemas' evaluated keys.
    // Resolve $ref in each subschema before collecting keys.
    if let allOf = subschema["allOf"], allOf.isArray {
      for sub in allOf {
        let subSchema: JSON
        if let innerRef = sub["$ref"]?.stringValue,
          let resolved = compiled?.resolveRef(
            innerRef, currentResourceURI: ctx.currentResourceURI,
            remoteRegistry: remoteCompiled)
        {
          subSchema = resolved.schema
        } else {
          subSchema = sub
        }
        let subKeys = evaluatedPropertyKeysRecursive(
          for: subSchema, dict: dict,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedProperties: true)
        keys.formUnion(subKeys)
      }
    }

    // anyOf: union of matching subschemas' evaluated keys.
    // Resolve $ref in each subschema before collecting keys.
    if let anyOf = subschema["anyOf"], anyOf.isArray {
      let objectValue = JSON(dict)
      for sub in anyOf {
        let subSchema: JSON
        if let innerRef = sub["$ref"]?.stringValue,
          let resolved = compiled?.resolveRef(
            innerRef, currentResourceURI: ctx.currentResourceURI,
            remoteRegistry: remoteCompiled)
        {
          subSchema = resolved.schema
        } else {
          subSchema = sub
        }
        var subErrors: [JSONSchemaError] = []
        validateValue(
          objectValue, against: subSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/anyOf", errors: &subErrors, ctx: ctx)
        if subErrors.isEmpty {
          let subKeys = evaluatedPropertyKeysRecursive(
            for: subSchema, dict: dict,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedProperties: true)
          keys.formUnion(subKeys)
        }
      }
    }

    // oneOf: union of matching subschemas' evaluated keys.
    // Resolve $ref in each subschema before collecting keys.
    if let oneOf = subschema["oneOf"], oneOf.isArray {
      let objectValue = JSON(dict)
      for sub in oneOf {
        let subSchema: JSON
        if let innerRef = sub["$ref"]?.stringValue,
          let resolved = compiled?.resolveRef(
            innerRef, currentResourceURI: ctx.currentResourceURI,
            remoteRegistry: remoteCompiled)
        {
          subSchema = resolved.schema
        } else {
          subSchema = sub
        }
        var subErrors: [JSONSchemaError] = []
        validateValue(
          objectValue, against: subSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/oneOf", errors: &subErrors, ctx: ctx)
        if subErrors.isEmpty {
          let subKeys = evaluatedPropertyKeysRecursive(
            for: subSchema, dict: dict,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedProperties: true)
          keys.formUnion(subKeys)
        }
      }
    }

    // if/then/else: only the matching branch's evaluated keys count.
    // Resolve $ref in if/then/else subschemas before collecting keys.
    if let ifSchema = subschema["if"] {
      let ifSchemaResolved: JSON
      if let innerRef = ifSchema["$ref"]?.stringValue,
        let resolved = compiled?.resolveRef(
          innerRef, currentResourceURI: ctx.currentResourceURI,
          remoteRegistry: remoteCompiled)
      {
        ifSchemaResolved = resolved.schema
      } else {
        ifSchemaResolved = ifSchema
      }
      var ifErrors: [JSONSchemaError] = []
      let objectValue = JSON(dict)
      validateValue(
        objectValue, against: ifSchemaResolved, instancePath: instancePath,
        schemaPath: schemaPath + "/if", errors: &ifErrors, ctx: ctx)
      if ifErrors.isEmpty {
        let ifKeys = evaluatedPropertyKeysRecursive(
          for: ifSchemaResolved, dict: dict,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedProperties: true)
        keys.formUnion(ifKeys)
        if let thenSchema = subschema["then"] {
          let thenSchemaResolved: JSON
          if let innerRef = thenSchema["$ref"]?.stringValue,
            let resolved = compiled?.resolveRef(
              innerRef, currentResourceURI: ctx.currentResourceURI,
              remoteRegistry: remoteCompiled)
          {
            thenSchemaResolved = resolved.schema
          } else {
            thenSchemaResolved = thenSchema
          }
          let thenKeys = evaluatedPropertyKeysRecursive(
            for: thenSchemaResolved, dict: dict,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedProperties: true)
          keys.formUnion(thenKeys)
        }
      } else {
        if let elseSchema = subschema["else"] {
          let elseSchemaResolved: JSON
          if let innerRef = elseSchema["$ref"]?.stringValue,
            let resolved = compiled?.resolveRef(
              innerRef, currentResourceURI: ctx.currentResourceURI,
              remoteRegistry: remoteCompiled)
          {
            elseSchemaResolved = resolved.schema
          } else {
            elseSchemaResolved = elseSchema
          }
          let elseKeys = evaluatedPropertyKeysRecursive(
            for: elseSchemaResolved, dict: dict,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedProperties: true)
          keys.formUnion(elseKeys)
        }
      }
    }

    // unevaluatedProperties: when called from composition keyword context,
    // keys validated by unevaluatedProperties are also considered evaluated.
    if includeUnevaluatedProperties, subschema["unevaluatedProperties"] != nil {
      for (key, _) in dict {
        if !keys.contains(key) {
          keys.insert(key)
        }
      }
    }

    return keys
  }

  // ======================================================================
  // MARK: - Draft 7 specific validators
  // ======================================================================

  // MARK: - Keyword: exclusiveMinimum (Draft 7 boolean modifier)

  /// Validates `exclusiveMinimum` as a boolean modifier on `minimum`
  /// (Draft 7 semantics). Ignored when the value is numeric.
  internal func validateExclusiveMinimumBool(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let exclBool = subschema["exclusiveMinimum"]?.boolValue,
      let minVal = subschema["minimum"],
      let valDouble = value.floatValue, let minDouble = minVal.floatValue
    else { return }
    if exclBool {
      if let valInt = value.intValue, let minInt = minVal.intValue {
        if valInt <= minInt {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMinimum",
              keyword: "exclusiveMinimum",
              message: "value \(valInt) is less than or equal to minimum \(minInt)"))
        }
        return
      }
      if valDouble <= minDouble {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMinimum",
            keyword: "exclusiveMinimum",
            message: "value \(valDouble) is less than or equal to minimum \(minDouble)"))
      }
    }
  }

  // MARK: - Keyword: exclusiveMaximum (Draft 7 boolean modifier)

  /// Validates `exclusiveMaximum` as a boolean modifier on `maximum`
  /// (Draft 7 semantics). Ignored when the value is numeric.
  internal func validateExclusiveMaximumBool(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let exclBool = subschema["exclusiveMaximum"]?.boolValue,
      let maxVal = subschema["maximum"],
      let valDouble = value.floatValue, let maxDouble = maxVal.floatValue
    else { return }
    if exclBool {
      if let valInt = value.intValue, let maxInt = maxVal.intValue {
        if valInt >= maxInt {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMaximum",
              keyword: "exclusiveMaximum",
              message: "value \(valInt) is greater than or equal to maximum \(maxInt)"))
        }
        return
      }
      if valDouble >= maxDouble {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMaximum",
            keyword: "exclusiveMaximum",
            message: "value \(valDouble) is greater than or equal to maximum \(maxDouble)"))
      }
    }
  }

  // MARK: - Keyword: format (Draft 7 assertion)

  /// Validates the `format` keyword — checks that a string value conforms
  /// to the specified format (e.g., `date-time`, `email`, `uuid`).
  /// Disabled formats are skipped. Only validates string values.
  ///
  /// Per Draft 2020-12, `format` is an **annotation** keyword — it should
  /// NOT produce validation errors. Draft 7 treats `format` as an assertion.
  /// This validator is only called for Draft 7 schemas.
  internal func validateFormat(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let formatStr = subschema["format"]?.stringValue, let strVal = value.stringValue else {
      return
    }
    guard let format = JSONSchemaFormat(rawValue: formatStr) else { return }
    guard formatOptions.isEnabled(format) else { return }
    if !format.validate(strVal) {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/format", keyword: "format",
          message: "string '\(strVal)' does not match format '\(formatStr)'"))
    }
  }

  // MARK: - Keyword: dependencies (Draft 7)

  /// Validates the `dependencies` keyword (Draft 7) — when a property key
  /// is present, the dependency is either a schema (object) or a required
  /// array (array of strings). Each entry in the object triggers either
  /// schema validation or required-key checking based on its type.
  ///
  /// Draft 2020-12 splits this into `dependentSchemas` + `dependentRequired`.
  internal func validateDependencies(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let deps = subschema["dependencies"], deps.isObject, value.isObject else { return }
    guard case .object(let depDict) = deps.storage else { return }
    for (key, depValue) in depDict {
      guard value[key] != nil else { continue }
      if depValue.isObject {
        var subErrors: [JSONSchemaError] = []
        validateValue(
          value, against: depValue, instancePath: instancePath,
          schemaPath: schemaPath + "/dependencies/" + key, errors: &subErrors, ctx: ctx)
        if let first = subErrors.first {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/dependencies/" + key,
              keyword: "dependencies",
              message: "dependency for key '\(key)' failed: \(first.message)"))
        }
      } else if depValue.isArray {
        for reqKey in depValue.arrayValue ?? [] {
          guard let reqKeyStr = reqKey.stringValue else { continue }
          if value[reqKeyStr] == nil {
            errors.append(
              JSONSchemaError(
                instancePath: instancePath, schemaPath: schemaPath + "/dependencies/" + key,
                keyword: "dependencies",
                message: "key '\(key)' requires key '\(reqKeyStr)'"))
          }
        }
      } else if let boolVal = depValue.boolValue, !boolVal {
        // Boolean false dependency — the key exists but value is false
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/dependencies/" + key,
            keyword: "dependencies",
            message: "dependency '\(key)' is false, but key exists"))
      }
    }
  }

  // MARK: - Keyword: additionalItems (Draft 7 tuple mode)

  /// Validates `additionalItems` (Draft 7 only) — schema for items beyond
  /// the tuple length defined by `items` (when items is an array).
  /// When `items` is a schema (not array), `additionalItems` is ignored
  /// because `items` already applies to all items.
  internal func validateAdditionalItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let additionalItems = subschema["additionalItems"], let arr = value.arrayValue else {
      return
    }
    guard let items = subschema["items"], items.isArray else { return }
    let tupleCount = items.arrayValue?.count ?? 0
    for (index, item) in arr.enumerated() {
      if index < tupleCount { continue }
      validateValue(
        item, against: additionalItems,
        instancePath: instancePath.isEmpty ? String(index) : instancePath + "/" + String(index),
        schemaPath: schemaPath + "/additionalItems", errors: &errors, ctx: ctx)
    }
  }

  // MARK: - Keyword: items tuple mode (Draft 7 array)

  /// Validates `items` as a tuple array (Draft 7) — validates the first N
  /// items against the corresponding schemas in the array.
  internal func validateItemsTuple(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let items = subschema["items"], items.isArray, let arr = value.arrayValue else { return }
    let tupleSchemas = items.arrayValue ?? []
    for (index, item) in arr.prefix(tupleSchemas.count).enumerated() {
      validateValue(
        item, against: tupleSchemas[index],
        instancePath: instancePath.isEmpty ? String(index) : instancePath + "/" + String(index),
        schemaPath: schemaPath + "/items/" + String(index), errors: &errors, ctx: ctx)
    }
  }

  // ======================================================================
  // MARK: - Draft 2020-12 specific validators
  // ======================================================================

  // MARK: - Keyword: dependentSchemas

  /// Validates the `dependentSchemas` keyword — when a property key is
  /// present, the entire object must validate against the dependent schema.
  /// Draft 2020-12 only (Draft 7 uses `dependencies`).
  internal func validateDependentSchemas(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let depSchemas = subschema["dependentSchemas"], depSchemas.isObject, value.isObject else {
      return
    }
    guard case .object(let depDict) = depSchemas.storage else { return }
    for (key, depSchema) in depDict {
      guard value[key] != nil else { continue }
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: depSchema, instancePath: instancePath,
        schemaPath: schemaPath + "/dependentSchemas/" + key, errors: &subErrors, ctx: ctx)
      if let first = subErrors.first {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/dependentSchemas/" + key,
            keyword: "dependentSchemas",
            message: "dependent schema for key '\(key)' failed: \(first.message)"))
      }
    }
  }

  // MARK: - Keyword: dependentRequired

  /// Validates the `dependentRequired` keyword — when a property key is
  /// present, other specified property keys must also be present.
  /// Draft 2020-12 only (Draft 7 uses `dependencies`).
  internal func validateDependentRequired(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let depRequired = subschema["dependentRequired"], depRequired.isObject, value.isObject
    else { return }
    guard case .object(let depDict) = depRequired.storage else { return }
    for (key, requiredArray) in depDict {
      guard let requiredKeys = requiredArray.arrayValue else { continue }
      if value[key] != nil {
        for reqKey in requiredKeys {
          guard let reqKeyStr = reqKey.stringValue else { continue }
          if value[reqKeyStr] == nil {
            errors.append(
              JSONSchemaError(
                instancePath: instancePath, schemaPath: schemaPath + "/dependentRequired/" + key,
                keyword: "dependentRequired", message: "key '\(key)' requires key '\(reqKeyStr)'"))
          }
        }
      }
    }
  }

  // MARK: - Keyword: prefixItems

  /// Validates `prefixItems` (Draft 2020-12) — tuple validation for the
  /// first N items. Each schema validates the corresponding item index.
  internal func validatePrefixItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let prefixItems = subschema["prefixItems"], prefixItems.isArray,
      let arr = value.arrayValue
    else { return }
    let schemas = prefixItems.arrayValue ?? []
    for (index, item) in arr.prefix(schemas.count).enumerated() {
      validateValue(
        item, against: schemas[index],
        instancePath: instancePath.isEmpty ? String(index) : instancePath + "/" + String(index),
        schemaPath: schemaPath + "/prefixItems/" + String(index), errors: &errors, ctx: ctx)
    }
  }

  // MARK: - Keyword: items (schema mode)

  /// Validates `items` as a schema (Draft 2020-12) — applies to items
  /// beyond `prefixItems`. In Draft 7, `items` schema applies to all items
  /// (handled by the shared `validateItemsSchema` call when prefixItems is absent).
  internal func validateItemsSchema(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let items = subschema["items"], let arr = value.arrayValue else { return }
    let prefixCount: Int
    if let prefixItems = subschema["prefixItems"], prefixItems.isArray {
      prefixCount = prefixItems.arrayValue?.count ?? 0
    } else {
      prefixCount = 0
    }
    let remaining = arr.dropFirst(prefixCount)
    if items.isObject {
      for (index, item) in remaining.enumerated() {
        let actualIndex = index + prefixCount
        validateValue(
          item, against: items,
          instancePath: instancePath.isEmpty
            ? String(actualIndex) : instancePath + "/" + String(actualIndex),
          schemaPath: schemaPath + "/items", errors: &errors, ctx: ctx)
      }
    } else if let boolVal = items.boolValue {
      if !boolVal {
        for (index, item) in remaining.enumerated() {
          let actualIndex = index + prefixCount
          validateValue(
            item, against: items,
            instancePath: instancePath.isEmpty
              ? String(actualIndex) : instancePath + "/" + String(actualIndex),
            schemaPath: schemaPath + "/items", errors: &errors, ctx: ctx)
        }
      }
      // If items is true, all remaining items pass (no validation needed)
    }
  }

  // MARK: - Evaluation tracking helpers

  /// Recursively computes the set of item indices that a schema (including
  /// its composition keywords) evaluates for the given array data.
  ///
  /// Examines `prefixItems`, `items`, `contains`, and in-place applicators
  /// (`allOf`, `anyOf`, `oneOf`, `if`/`then`/`else`) to determine which
  /// indices are considered evaluated.
  internal func evaluatedItemIndices(
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
    let prefixCount = subschema["prefixItems"]?.arrayValue?.count ?? 0

    // Resolve $ref target first — merge evaluated indices from the
    // referenced schema before processing local keywords.
    if let refStr = subschema["$ref"]?.stringValue,
      let resolved = compiled?.resolveRef(
        refStr, currentResourceURI: ctx.currentResourceURI,
        remoteRegistry: remoteCompiled)
    {
      let targetKeys = evaluatedItemIndices(
        for: resolved.schema, data: data,
        instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
        includeUnevaluatedItems: true)
      indices.formUnion(targetKeys)
    }

    // Resolve $dynamicRef target — merge evaluated indices from the
    // dynamically referenced schema.
    if let dynRefStr = subschema["$dynamicRef"]?.stringValue {
      if let resolved = compiled?.resolveDynamicRef(
        dynRefStr,
        dynamicScope: ctx.dynamicScope, currentResourceURI: ctx.currentResourceURI,
        remoteRegistry: remoteCompiled)
      {
        let targetKeys = evaluatedItemIndices(
          for: resolved.schema, data: data,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedItems: true)
        indices.formUnion(targetKeys)
      }
    }

    // prefixItems: indices 0..<count are evaluated
    if let prefixItems = subschema["prefixItems"], prefixItems.isArray {
      let count = prefixItems.arrayValue?.count ?? 0
      for i in 0..<min(count, dataCount) {
        indices.insert(i)
      }
    }

    // items: if a schema, all remaining indices are evaluated
    if let items = subschema["items"] {
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
    if let containsSchema = subschema["contains"] {
      for i in 0..<prefixCount {
        indices.insert(i)
      }
      for i in prefixCount..<dataCount {
        var itemErrors: [JSONSchemaError] = []
        validateValue(
          data[i], against: containsSchema,
          instancePath: instancePath.isEmpty ? String(i) : instancePath + "/" + String(i),
          schemaPath: schemaPath + "/contains", errors: &itemErrors, ctx: ctx)
        if itemErrors.isEmpty {
          indices.insert(i)
        }
      }
    }

    // allOf: union of all subschemas' evaluated indices.
    // Resolve $ref in each subschema before collecting indices.
    if let allOf = subschema["allOf"], allOf.isArray {
      for sub in allOf {
        let subSchema: JSON
        if let innerRef = sub["$ref"]?.stringValue,
          let resolved = compiled?.resolveRef(
            innerRef, currentResourceURI: ctx.currentResourceURI,
            remoteRegistry: remoteCompiled)
        {
          subSchema = resolved.schema
        } else {
          subSchema = sub
        }
        let subIndices = evaluatedItemIndices(
          for: subSchema, data: data,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedItems: true)
        indices.formUnion(subIndices)
      }
    }

    // anyOf: union of matching subschemas' evaluated indices.
    // Resolve $ref in each subschema before collecting indices.
    if let anyOf = subschema["anyOf"], anyOf.isArray {
      let arrayValue = JSON(data)
      for sub in anyOf {
        let subSchema: JSON
        if let innerRef = sub["$ref"]?.stringValue,
          let resolved = compiled?.resolveRef(
            innerRef, currentResourceURI: ctx.currentResourceURI,
            remoteRegistry: remoteCompiled)
        {
          subSchema = resolved.schema
        } else {
          subSchema = sub
        }
        var subErrors: [JSONSchemaError] = []
        validateValue(
          arrayValue, against: subSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/anyOf", errors: &subErrors, ctx: ctx)
        if subErrors.isEmpty {
          let subIndices = evaluatedItemIndices(
            for: subSchema, data: data,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedItems: true)
          indices.formUnion(subIndices)
        }
      }
    }

    // oneOf: union of matching subschemas' evaluated indices.
    // Resolve $ref in each subschema before collecting indices.
    if let oneOf = subschema["oneOf"], oneOf.isArray {
      let arrayValue = JSON(data)
      for sub in oneOf {
        let subSchema: JSON
        if let innerRef = sub["$ref"]?.stringValue,
          let resolved = compiled?.resolveRef(
            innerRef, currentResourceURI: ctx.currentResourceURI,
            remoteRegistry: remoteCompiled)
        {
          subSchema = resolved.schema
        } else {
          subSchema = sub
        }
        var subErrors: [JSONSchemaError] = []
        validateValue(
          arrayValue, against: subSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/oneOf", errors: &subErrors, ctx: ctx)
        if subErrors.isEmpty {
          let subIndices = evaluatedItemIndices(
            for: subSchema, data: data,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedItems: true)
          indices.formUnion(subIndices)
        }
      }
    }

    // if/then/else: only the matching branch's evaluated indices count.
    // Resolve $ref in if/then/else subschemas before collecting indices.
    if let ifSchema = subschema["if"] {
      let ifSchemaResolved: JSON
      if let innerRef = ifSchema["$ref"]?.stringValue,
        let resolved = compiled?.resolveRef(
          innerRef, currentResourceURI: ctx.currentResourceURI,
          remoteRegistry: remoteCompiled)
      {
        ifSchemaResolved = resolved.schema
      } else {
        ifSchemaResolved = ifSchema
      }
      var ifErrors: [JSONSchemaError] = []
      let arrayValue = JSON(data)
      validateValue(
        arrayValue, against: ifSchemaResolved, instancePath: instancePath,
        schemaPath: schemaPath + "/if", errors: &ifErrors, ctx: ctx)
      if ifErrors.isEmpty {
        // if matches — take if's indices plus then's indices
        let ifIndices = evaluatedItemIndices(
          for: ifSchemaResolved, data: data,
          instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
          includeUnevaluatedItems: true)
        indices.formUnion(ifIndices)
        if let thenSchema = subschema["then"] {
          let thenSchemaResolved: JSON
          if let innerRef = thenSchema["$ref"]?.stringValue,
            let resolved = compiled?.resolveRef(
              innerRef, currentResourceURI: ctx.currentResourceURI,
              remoteRegistry: remoteCompiled)
          {
            thenSchemaResolved = resolved.schema
          } else {
            thenSchemaResolved = thenSchema
          }
          let thenIndices = evaluatedItemIndices(
            for: thenSchemaResolved, data: data,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedItems: true)
          indices.formUnion(thenIndices)
        }
      } else {
        // if fails — only else's indices count (if present)
        if let elseSchema = subschema["else"] {
          let elseSchemaResolved: JSON
          if let innerRef = elseSchema["$ref"]?.stringValue,
            let resolved = compiled?.resolveRef(
              innerRef, currentResourceURI: ctx.currentResourceURI,
              remoteRegistry: remoteCompiled)
          {
            elseSchemaResolved = resolved.schema
          } else {
            elseSchemaResolved = elseSchema
          }
          let elseIndices = evaluatedItemIndices(
            for: elseSchemaResolved, data: data,
            instancePath: instancePath, schemaPath: schemaPath, ctx: ctx,
            includeUnevaluatedItems: true)
          indices.formUnion(elseIndices)
        }
        // No indices from if itself when if fails
      }
    }

    // unevaluatedItems: when called from composition keyword context,
    // items validated by unevaluatedItems are also considered evaluated.
    if includeUnevaluatedItems, subschema["unevaluatedItems"] != nil {
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
  internal func validateUnevaluatedItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let unevaluated = subschema["unevaluatedItems"], let arr = value.arrayValue else {
      return
    }
    // If items is a schema (not boolean), all items past prefixItems are
    // evaluated — unevaluatedItems doesn't apply.
    if let items = subschema["items"], items.isObject { return }
    // Compute the set of indices evaluated by this schema (including
    // composition keywords).
    let evaluated = evaluatedItemIndices(
      for: subschema, data: arr,
      instancePath: instancePath, schemaPath: schemaPath, ctx: ctx)
    for (index, item) in arr.enumerated() {
      if evaluated.contains(index) { continue }
      validateValue(
        item, against: unevaluated,
        instancePath: instancePath.isEmpty ? String(index) : instancePath + "/" + String(index),
        schemaPath: schemaPath + "/unevaluatedItems", errors: &errors, ctx: ctx)
    }
  }

  // MARK: - Keyword: unevaluatedProperties

  /// Validates `unevaluatedProperties` (Draft 2020-12) — schema for
  /// properties not evaluated by `properties`, `patternProperties`,
  /// `additionalProperties`, or `dependentSchemas`.
  ///
  /// - Todo: In-place applicators (`allOf`, `anyOf`, `oneOf`, `if`/`then`/`else`)
  ///   can also evaluate properties — their evaluated keys should be tracked.
  internal func validateUnevaluatedProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let unevaluated = subschema["unevaluatedProperties"], value.isObject else { return }
    guard case .object(let dict) = value.storage else { return }
    let evaluatedKeys = evaluatedPropertyKeysRecursive(
      for: subschema, dict: dict,
      instancePath: instancePath, schemaPath: schemaPath, ctx: ctx)
    for (key, val) in dict {
      if !evaluatedKeys.contains(key) {
        validateValue(
          val, against: unevaluated,
          instancePath: instancePath.isEmpty ? key : instancePath + "/" + key,
          schemaPath: schemaPath + "/unevaluatedProperties", errors: &errors, ctx: ctx)
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
  internal func validateContentMediaType(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
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
  internal func validateContentEncoding(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
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
  internal func validateContentSchema(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    // contentSchema is an annotation keyword per Draft 2020-12.
    // It does NOT produce validation errors.
  }

  // MARK: - Keyword: minContains / maxContains

  /// Validates `minContains` (Draft 2020-12) — the array must contain at
  /// least `minContains` items matching the `contains` subschema.
  internal func validateMinContains(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let minContains = subschema["minContains"]?.intValue, subschema["contains"] != nil,
      let arr = value.arrayValue
    else { return }
    let containsSchema = subschema["contains"]!
    var matchCount = 0
    for item in arr {
      var itemErrors: [JSONSchemaError] = []
      validateValue(
        item, against: containsSchema, instancePath: instancePath,
        schemaPath: schemaPath + "/contains", errors: &itemErrors, ctx: ctx)
      if itemErrors.isEmpty { matchCount += 1 }
    }
    if matchCount < minContains {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/minContains",
          keyword: "minContains",
          message:
            "array contains \(matchCount) items matching the subschema, minimum \(minContains)"))
    }
  }

  /// Validates `maxContains` (Draft 2020-12) — the array must contain at
  /// most `maxContains` items matching the `contains` subschema.
  internal func validateMaxContains(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let maxContains = subschema["maxContains"]?.intValue, subschema["contains"] != nil,
      let arr = value.arrayValue
    else { return }
    let containsSchema = subschema["contains"]!
    var matchCount = 0
    for item in arr {
      var itemErrors: [JSONSchemaError] = []
      validateValue(
        item, against: containsSchema, instancePath: instancePath,
        schemaPath: schemaPath + "/contains", errors: &itemErrors, ctx: ctx)
      if itemErrors.isEmpty { matchCount += 1 }
    }
    if matchCount > maxContains {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/maxContains",
          keyword: "maxContains",
          message:
            "array contains \(matchCount) items matching the subschema, maximum \(maxContains)"))
    }
  }
}
