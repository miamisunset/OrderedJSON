import Foundation
import OrderedCollections

extension JSONSchema {

  // MARK: - Keyword: pattern

  /// Validates the `pattern` keyword — checks that a string value matches
  /// the given regex. Non-string values are skipped.
  func validatePattern(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let patternStr = subschema[key: .pattern]?.stringValue, let strVal = value.stringValue
    else {
      return
    }
    // Use pre-compiled regex if available, otherwise compile on the fly.
    let regex: NSRegularExpression
    if let compiled = compiled,
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
          instancePath: instancePath, schemaPath: schemaPath + "/pattern", keyword: .pattern,
          message: "string '\(strVal)' does not match pattern '\(patternStr)'"
        )
      )
    }
  }

  // MARK: - Keyword: enum

  /// Validates the `enum` keyword — checks that the value matches at least
  /// one of the allowed values using schema-aware equality.
  func validateEnum(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let enumValues = subschema[key: .enum], enumValues.isArray else { return }
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
          instancePath: instancePath, schemaPath: schemaPath + "/enum", keyword: .enum,
          message: "value does not match any of the allowed values in enum"
        )
      )
    }
  }

  // MARK: - Keyword: const

  /// Validates the `const` keyword — checks that the value is exactly equal
  /// to the const value using schema-aware equality.
  func validateConst(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let constVal = subschema[key: .const] else { return }
    if !JSONSchema.schemaEqual(value, constVal) {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/const", keyword: .const,
          message: "value does not match the const value"
        )
      )
    }
  }

  // MARK: - Keyword: minLength

  /// Validates the `minLength` keyword — checks that the string's code point
  /// count (`unicodeScalars.count`) meets the minimum. Per RFC 8259, length
  /// is measured in code points, not grapheme clusters.
  func validateMinLength(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let minLen = subschema[key: .minLength]?.intValue, let strVal = value.stringValue else {
      return
    }
    let count = strVal.unicodeScalars.count
    if count < minLen {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/minLength", keyword: .minLength,
          message: "string length \(count) code points is less than minimum \(minLen)"
        )
      )
    }
  }

  // MARK: - Keyword: maxLength

  /// Validates the `maxLength` keyword — checks that the string's code point
  /// count (`unicodeScalars.count`) does not exceed the maximum.
  func validateMaxLength(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let maxLen = subschema[key: .maxLength]?.intValue, let strVal = value.stringValue else {
      return
    }
    let count = strVal.unicodeScalars.count
    if count > maxLen {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/maxLength", keyword: .maxLength,
          message: "string length \(count) code points is greater than maximum \(maxLen)"
        )
      )
    }
  }
}
