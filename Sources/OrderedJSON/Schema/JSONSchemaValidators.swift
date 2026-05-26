import Foundation
import OrderedCollections

extension JSONSchema {

  // MARK: - Keyword: type

  /// Validates the `type` keyword — checks that the value's type matches one
  /// of the allowed types. Integers are allowed for `number` type.
  internal func validateType(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError]
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
    errors: inout [JSONSchemaError]
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
          schemaPath: childSchemaPath, errors: &errors)
      }
    }
  }

  // MARK: - Keyword: required

  /// Validates the `required` keyword — checks that all required property
  /// keys are present (presence only, not null-rejecting).
  internal func validateRequired(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError]
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
    errors: inout [JSONSchemaError]
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
    errors: inout [JSONSchemaError]
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
    errors: inout [JSONSchemaError]
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
    errors: inout [JSONSchemaError]
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
    errors: inout [JSONSchemaError]
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
    errors: inout [JSONSchemaError]
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
    errors: inout [JSONSchemaError]
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
    errors: inout [JSONSchemaError]
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
    errors: inout [JSONSchemaError]
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
    errors: inout [JSONSchemaError]
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
    errors: inout [JSONSchemaError]
  ) {
    guard let allOf = subschema["allOf"], allOf.isArray else { return }

    for (index, sub) in allOf.enumerated() {
      let subSchemaPath = schemaPath + "/allOf/" + String(index)
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath, schemaPath: subSchemaPath,
        errors: &subErrors)
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
    errors: inout [JSONSchemaError]
  ) {
    guard let anyOf = subschema["anyOf"], anyOf.isArray else { return }

    var matched = false
    for sub in anyOf {
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath, schemaPath: schemaPath, errors: &subErrors)
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
    errors: inout [JSONSchemaError]
  ) {
    guard let oneOf = subschema["oneOf"], oneOf.isArray else { return }

    var matchCount = 0
    for sub in oneOf {
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath, schemaPath: schemaPath, errors: &subErrors)
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
    errors: inout [JSONSchemaError]
  ) {
    guard subschema["not"] != nil else { return }
    let notSchema = subschema["not"]!

    var subErrors: [JSONSchemaError] = []
    validateValue(
      value, against: notSchema, instancePath: instancePath, schemaPath: schemaPath + "/not",
      errors: &subErrors)

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
    errors: inout [JSONSchemaError]
  ) {
    guard let ifSchema = subschema["if"] else { return }

    var ifErrors: [JSONSchemaError] = []
    validateValue(
      value, against: ifSchema, instancePath: instancePath, schemaPath: schemaPath + "/if",
      errors: &ifErrors)

    let ifValid = ifErrors.isEmpty

    if ifValid {
      if let thenSchema = subschema["then"] {
        var thenErrors: [JSONSchemaError] = []
        validateValue(
          value, against: thenSchema, instancePath: instancePath, schemaPath: schemaPath + "/then",
          errors: &thenErrors)
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
          errors: &elseErrors)
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
    errors: inout [JSONSchemaError]
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
          schemaPath: schemaPath + "/dependentSchemas/" + key, errors: &subErrors)
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
    errors: inout [JSONSchemaError]
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
}
