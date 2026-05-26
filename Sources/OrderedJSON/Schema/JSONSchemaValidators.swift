import Foundation
import OrderedCollections

extension JSONSchema {

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
  internal func typeNameOf(_ value: JSON) -> String {
    switch value.storage {
    case .null: return "null"
    case .boolean: return "boolean"
    case .number(.integer): return "integer"
    case .number(.float): return "number"
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
        let childInstancePath = instancePath.isEmpty ? key : instancePath + "/" + key
        validateValue(
          childValue, against: propSchema, instancePath: childInstancePath,
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

  // MARK: - Keyword: exclusiveMinimum

  /// Validates `exclusiveMinimum` — Draft 2020-12 uses a numeric bound
  /// (strictly greater than), Draft 7 uses a boolean modifier on `minimum`.
  internal func validateExclusiveMinimum(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let exclMin = subschema["exclusiveMinimum"] else { return }

    if draft == .draft7 {
      guard let exclBool = exclMin.boolValue, let minVal = subschema["minimum"] else { return }
      guard let valDouble = value.floatValue, let minDouble = minVal.floatValue else { return }

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
    } else {
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
  }

  // MARK: - Keyword: exclusiveMaximum

  /// Validates `exclusiveMaximum` — Draft 2020-12 uses a numeric bound
  /// (strictly less than), Draft 7 uses a boolean modifier on `maximum`.
  internal func validateExclusiveMaximum(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let exclMax = subschema["exclusiveMaximum"] else { return }

    if draft == .draft7 {
      guard let exclBool = exclMax.boolValue, let maxVal = subschema["maximum"] else { return }
      guard let valDouble = value.floatValue, let maxDouble = maxVal.floatValue else { return }

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
    } else {
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
  }

  // MARK: - Keyword: multipleOf

  /// Validates the `multipleOf` keyword — checks that the numeric value
  /// is a multiple of the given divisor. Zero and negative divisors are
  /// ignored per spec.
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
      let remainder = valDouble.truncatingRemainder(dividingBy: mDouble)
      let epsilon = max(1e-12 * mDouble, 1e-12)
      if abs(remainder) > epsilon && abs(remainder - mDouble) > epsilon {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/multipleOf",
            keyword: "multipleOf", message: "\(valDouble) is not a multiple of \(mDouble)"))
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
    guard let regex = try? NSRegularExpression(pattern: patternStr, options: []) else { return }

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
    guard let minLen = subschema["minLength"], let minLenVal = minLen.intValue,
      let strVal = value.stringValue
    else { return }
    let codePointCount = strVal.unicodeScalars.count
    if codePointCount < minLenVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/minLength", keyword: "minLength",
          message: "string length \(codePointCount) code points is less than minimum \(minLenVal)"))
    }
  }

  // MARK: - Keyword: maxLength

  /// Validates the `maxLength` keyword — checks that the string's code point
  /// count (`unicodeScalars.count`) does not exceed the maximum.
  internal func validateMaxLength(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let maxLen = subschema["maxLength"], let maxLenVal = maxLen.intValue,
      let strVal = value.stringValue
    else { return }
    let codePointCount = strVal.unicodeScalars.count
    if codePointCount > maxLenVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/maxLength", keyword: "maxLength",
          message:
            "string length \(codePointCount) code points is greater than maximum \(maxLenVal)"))
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
      let subSchemaPath = schemaPath + "/allOf/" + String(index)
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath, schemaPath: subSchemaPath,
        errors: &subErrors, ctx: ctx)
      if let firstError = subErrors.first {
        errors.append(
          JSONSchemaError(
            instancePath: firstError.instancePath.isEmpty ? instancePath : firstError.instancePath,
            schemaPath: subSchemaPath, keyword: "allOf",
            message: "subschema #\(index) failed: \(firstError.message)"))
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
        value, against: sub, instancePath: instancePath, schemaPath: schemaPath, errors: &subErrors,
        ctx: ctx)
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
        value, against: sub, instancePath: instancePath, schemaPath: schemaPath, errors: &subErrors,
        ctx: ctx)
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
    let notSchema = subschema["not"]!

    var subErrors: [JSONSchemaError] = []
    validateValue(
      value, against: notSchema, instancePath: instancePath, schemaPath: schemaPath + "/not",
      errors: &subErrors, ctx: ctx)

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
      value, against: ifSchema, instancePath: instancePath, schemaPath: schemaPath + "/if",
      errors: &ifErrors, ctx: ctx)

    let ifValid = ifErrors.isEmpty

    if ifValid {
      if let thenSchema = subschema["then"] {
        var thenErrors: [JSONSchemaError] = []
        validateValue(
          value, against: thenSchema, instancePath: instancePath, schemaPath: schemaPath + "/then",
          errors: &thenErrors, ctx: ctx)
        if let firstError = thenErrors.first {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/then", keyword: "then",
              message: "then schema failed: \(firstError.message)"))
        }
      }
    } else {
      if let elseSchema = subschema["else"] {
        var elseErrors: [JSONSchemaError] = []
        validateValue(
          value, against: elseSchema, instancePath: instancePath, schemaPath: schemaPath + "/else",
          errors: &elseErrors, ctx: ctx)
        if let firstError = elseErrors.first {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/else", keyword: "else",
              message: "else schema failed: \(firstError.message)"))
        }
      }
    }
  }

  // MARK: - Composition: dependentSchemas

  /// Validates the `dependentSchemas` keyword — when a property key is
  /// present, the entire object must validate against the dependent schema.
  internal func validateDependentSchemas(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let depSchemas = subschema["dependentSchemas"], depSchemas.isObject, value.isObject else {
      return
    }
    guard case .object(let depDict) = depSchemas.storage else { return }

    for (key, depSchema) in depDict {
      if value[key] != nil {
        var subErrors: [JSONSchemaError] = []
        validateValue(
          value, against: depSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/dependentSchemas/" + key, errors: &subErrors,
          ctx: ctx)
        if let firstError = subErrors.first {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/dependentSchemas/" + key,
              keyword: "dependentSchemas",
              message: "dependent schema for key '\(key)' failed: \(firstError.message)"))
        }
      }
    }
  }

  // MARK: - Composition: dependentRequired

  /// Validates the `dependentRequired` keyword — when a property key is
  /// present, other specified property keys must also be present.
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

  // MARK: - Keyword: items

  /// Validates the `items` keyword.
  /// - Draft 2020-12: schema applies to all array items (after `prefixItems`).
  /// - Draft 7: can be a schema (all items) or an array of schemas (tuple).
  ///   `prefixItems` does not exist in Draft 7, so `items` always applies to all items.
  internal func validateItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let items = subschema["items"], let arr = value.arrayValue else { return }

    if draft == .draft7, items.isArray {
      // Draft 7 tuple mode: items array validates first N items
      let tupleSchemas = items.arrayValue ?? []
      for (index, item) in arr.prefix(tupleSchemas.count).enumerated() {
        let childSchemaPath = schemaPath + "/items/" + String(index)
        let childInstancePath =
          instancePath.isEmpty ? String(index) : instancePath + "/" + String(index)
        validateValue(
          item, against: tupleSchemas[index], instancePath: childInstancePath,
          schemaPath: childSchemaPath, errors: &errors, ctx: ctx)
      }
    } else {
      // Schema mode: apply to all items (Draft 2020-12) or remaining items (Draft 7)
      for (index, item) in arr.enumerated() {
        let childSchemaPath = schemaPath + "/items"
        let childInstancePath =
          instancePath.isEmpty ? String(index) : instancePath + "/" + String(index)
        validateValue(
          item, against: items, instancePath: childInstancePath,
          schemaPath: childSchemaPath, errors: &errors, ctx: ctx)
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
      let childSchemaPath = schemaPath + "/prefixItems/" + String(index)
      let childInstancePath =
        instancePath.isEmpty ? String(index) : instancePath + "/" + String(index)
      validateValue(
        item, against: schemas[index], instancePath: childInstancePath,
        schemaPath: childSchemaPath, errors: &errors, ctx: ctx)
    }
  }

  // MARK: - Keyword: additionalItems

  /// Validates `additionalItems` (Draft 7 only) — schema for items beyond
  /// the tuple length defined by `items` (when items is an array).
  internal func validateAdditionalItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let additionalItems = subschema["additionalItems"], let arr = value.arrayValue
    else { return }

    let tupleCount: Int
    if let items = subschema["items"], items.isArray {
      tupleCount = items.arrayValue?.count ?? 0
    } else {
      tupleCount = 0
    }

    for (index, item) in arr.enumerated() {
      if index < tupleCount { continue }
      let childSchemaPath = schemaPath + "/additionalItems"
      let childInstancePath =
        instancePath.isEmpty ? String(index) : instancePath + "/" + String(index)
      validateValue(
        item, against: additionalItems, instancePath: childInstancePath,
        schemaPath: childSchemaPath, errors: &errors, ctx: ctx)
    }
  }

  // MARK: - Keyword: minItems / maxItems

  /// Validates `minItems` — checks that the array has at least the
  /// specified number of items.
  internal func validateMinItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let minVal = subschema["minItems"]?.intValue, let arr = value.arrayValue
    else { return }
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
    guard let maxVal = subschema["maxItems"]?.intValue, let arr = value.arrayValue
    else { return }
    if arr.count > maxVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/maxItems", keyword: "maxItems",
          message: "array length \(arr.count) is greater than maximum \(maxVal)"))
    }
  }

  // MARK: - Keyword: uniqueItems

  /// Validates `uniqueItems` — checks that all items in the array are
  /// unique (using schema-aware equality).
  internal func validateUniqueItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard subschema["uniqueItems"]?.boolValue == true, let arr = value.arrayValue
    else { return }

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

  // MARK: - Keyword: contains

  /// Validates `contains` — checks that at least one item in the array
  /// matches the subschema.
  internal func validateContains(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let containsSchema = subschema["contains"], let arr = value.arrayValue
    else { return }

    for item in arr {
      var itemErrors: [JSONSchemaError] = []
      validateValue(
        item, against: containsSchema, instancePath: instancePath,
        schemaPath: schemaPath + "/contains", errors: &itemErrors, ctx: ctx)
      if itemErrors.isEmpty { return }
    }

    errors.append(
      JSONSchemaError(
        instancePath: instancePath, schemaPath: schemaPath + "/contains", keyword: "contains",
        message: "array does not contain an item matching the subschema"))
  }

  // MARK: - Keyword: minProperties / maxProperties

  /// Validates `minProperties` — checks that the object has at least the
  /// specified number of properties.
  internal func validateMinProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let minVal = subschema["minProperties"]?.intValue, value.isObject
    else { return }
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
    guard let maxVal = subschema["maxProperties"]?.intValue, value.isObject
    else { return }
    if value.count > maxVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/maxProperties",
          keyword: "maxProperties",
          message: "object has \(value.count) properties, greater than maximum \(maxVal)"))
    }
  }

  // MARK: - Keyword: propertyNames

  /// Validates `propertyNames` — each property key in the object must
  /// validate against the schema (the schema validates the key string).
  internal func validatePropertyNames(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let pnSchema = subschema["propertyNames"], value.isObject
    else { return }
    guard case .object(let dict) = value.storage else { return }

    for (key, _) in dict {
      var keyErrors: [JSONSchemaError] = []
      let keyJSON: JSON = .string(key)
      let childSchemaPath = schemaPath + "/propertyNames"
      let childInstancePath = instancePath.isEmpty ? "~" + key : instancePath + "/~" + key
      validateValue(
        keyJSON, against: pnSchema, instancePath: childInstancePath,
        schemaPath: childSchemaPath, errors: &keyErrors, ctx: ctx)
      if let firstError = keyErrors.first {
        errors.append(
          JSONSchemaError(
            instancePath: childInstancePath, schemaPath: childSchemaPath,
            keyword: "propertyNames",
            message: "property name '\(key)' failed: \(firstError.message)"))
      }
    }
  }

  // MARK: - Keyword: patternProperties

  /// Validates `patternProperties` — property keys matching a regex must
  /// have their value validated against the corresponding schema.
  internal func validatePatternProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let pp = subschema["patternProperties"], pp.isObject, value.isObject
    else { return }
    guard case .object(let patternDict) = pp.storage, case .object(let dict) = value.storage
    else { return }

    for (pattern, schema) in patternDict {
      // Regex was validated at init time by validatePatterns — safe to force-unwrap
      let regex = try! NSRegularExpression(pattern: pattern, options: [])
      for (key, val) in dict {
        let range = NSRange(key.startIndex..<key.endIndex, in: key)
        if regex.firstMatch(in: key, options: [], range: range) != nil {
          let childSchemaPath = schemaPath + "/patternProperties/" + pattern
          let childInstancePath = instancePath.isEmpty ? key : instancePath + "/" + key
          validateValue(
            val, against: schema, instancePath: childInstancePath,
            schemaPath: childSchemaPath, errors: &errors, ctx: ctx)
        }
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

    // Keys listed in properties are always evaluated
    if let properties = subschema["properties"], properties.isObject {
      guard case .object(let props) = properties.storage else {
        preconditionFailure("properties.isObject was true but storage pattern match failed")
      }
      for (key, _) in props {
        keys.insert(key)
      }
    }

    // Keys matched by patternProperties are evaluated
    if let pp = subschema["patternProperties"], pp.isObject {
      guard case .object(let patternDict) = pp.storage else {
        preconditionFailure("patternProperties.isObject was true but storage pattern match failed")
      }
      for (pattern, _) in patternDict {
        // Regex was validated at init time by validatePatterns — safe to force-unwrap
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        for (key, _) in dict {
          let range = NSRange(key.startIndex..<key.endIndex, in: key)
          if regex.firstMatch(in: key, options: [], range: range) != nil {
            keys.insert(key)
          }
        }
      }
    }

    // Keys evaluated by additionalProperties are also considered evaluated
    // (relevant for unevaluatedProperties, which must not re-check them)
    if includeAdditionalProperties, subschema["additionalProperties"] != nil {
      // additionalProperties evaluates every key not covered by properties/patternProperties,
      // so in practice all keys in dict are evaluated. We don't need to enumerate them.
      for (key, _) in dict {
        keys.insert(key)
      }
    }

    // Keys evaluated by dependentSchemas (key presence triggers evaluation)
    // A dependent schema key is evaluated if that key exists in the instance.
    if let depSchemas = subschema["dependentSchemas"], depSchemas.isObject {
      guard case .object(let depDict) = depSchemas.storage else {
        preconditionFailure("dependentSchemas.isObject was true but storage pattern match failed")
      }
      for (key, _) in depDict {
        if dict[key] != nil {
          keys.insert(key)
        }
      }
    }

    return keys
  }

  // MARK: - Keyword: additionalProperties

  /// Validates `additionalProperties` (Draft 7) — schema for properties
  /// not covered by `properties` or `patternProperties`.
  internal func validateAdditionalProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let additionalProperties = subschema["additionalProperties"], value.isObject
    else { return }
    guard case .object(let dict) = value.storage else { return }

    let coveredKeys = evaluatedPropertyKeys(
      for: subschema, from: dict, includeAdditionalProperties: false)

    for (key, val) in dict {
      if !coveredKeys.contains(key) {
        let childSchemaPath = schemaPath + "/additionalProperties"
        let childInstancePath = instancePath.isEmpty ? key : instancePath + "/" + key
        validateValue(
          val, against: additionalProperties, instancePath: childInstancePath,
          schemaPath: childSchemaPath, errors: &errors, ctx: ctx)
      }
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
    guard let unevaluated = subschema["unevaluatedProperties"], value.isObject
    else { return }
    guard case .object(let dict) = value.storage else { return }

    let evaluatedKeys = evaluatedPropertyKeys(
      for: subschema, from: dict, includeAdditionalProperties: true)

    for (key, val) in dict {
      if !evaluatedKeys.contains(key) {
        let childSchemaPath = schemaPath + "/unevaluatedProperties"
        let childInstancePath = instancePath.isEmpty ? key : instancePath + "/" + key
        validateValue(
          val, against: unevaluated, instancePath: childInstancePath,
          schemaPath: childSchemaPath, errors: &errors, ctx: ctx)
      }
    }
  }

  // MARK: - Keyword: unevaluatedItems

  /// Validates `unevaluatedItems` (Draft 2020-12) — schema for items not
  /// evaluated by `prefixItems`, `items`, or `contains`.
  ///
  /// - Note: If `items` is present as a schema, all items past `prefixItems`
  ///   are evaluated by `items`, making `unevaluatedItems` a no-op.
  /// - Todo: Track `contains` match indices — items matched by `contains`
  ///   are also evaluated and should be excluded from `unevaluatedItems`.
  internal func validateUnevaluatedItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let unevaluated = subschema["unevaluatedItems"], let arr = value.arrayValue
    else { return }

    // If `items` is present as a schema (not array/tuple), it evaluates all
    // items past prefixItems, so unevaluatedItems has nothing to evaluate.
    // Tuple-mode items (Draft 7 array) only evaluates indices < tuple length,
    // so unevaluatedItems still applies to items beyond that — no short-circuit.
    if let items = subschema["items"], items.isObject { return }

    // Determine which items were evaluated by prefixItems
    let prefixCount: Int
    if let prefixItems = subschema["prefixItems"], prefixItems.isArray {
      prefixCount = prefixItems.arrayValue?.count ?? 0
    } else {
      prefixCount = 0
    }

    // TODO: Also exclude items matched by `contains` — those indices are evaluated.
    for (index, item) in arr.enumerated() {
      if index < prefixCount { continue }
      let childSchemaPath = schemaPath + "/unevaluatedItems"
      let childInstancePath =
        instancePath.isEmpty ? String(index) : instancePath + "/" + String(index)
      validateValue(
        item, against: unevaluated, instancePath: childInstancePath,
        schemaPath: childSchemaPath, errors: &errors, ctx: ctx)
    }
  }
}
