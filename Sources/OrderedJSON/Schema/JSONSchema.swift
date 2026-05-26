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
/// let result = schema.validate(doc)
/// print(result.valid)  // true
/// ```
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
    guard schema.isObject else {
      throw JSONSchemaError(
        instancePath: "",
        schemaPath: "",
        keyword: "schema",
        message: "Schema must be a JSON object"
      )
    }

    self.schemaJSON = schema
    self.draft = resolvedDraft
  }

  /// Detects the JSON Schema draft from the `$schema` keyword.
  /// - Parameter schema: The schema JSON.
  /// - Returns: The detected draft, or `.draft202012` if unknown/missing.
  internal static func detectDraft(from schema: JSON) -> Draft {
    guard let schemaStr = schema["$schema"]?.stringValue else {
      return .draft202012
    }

    if schemaStr.contains("draft-07") || schemaStr.contains("draft-7") {
      return .draft7
    }
    if schemaStr.contains("2020-12") || schemaStr.contains("draft/2020-12") {
      return .draft202012
    }
    // Default to latest
    return .draft202012
  }

  /// Validates a JSON document against this schema.
  ///
  /// Returns a `JSONSchemaResult` containing all validation errors (if any).
  /// Does **not** throw — errors are collected into the result.
  ///
  /// - Parameter document: The JSON document to validate.
  /// - Returns: A validation result.
  public func validate(_ document: JSON) -> JSONSchemaResult {
    var errors: [JSONSchemaError] = []
    validateValue(document, against: schemaJSON, instancePath: "", schemaPath: "", errors: &errors)
    return JSONSchemaResult(valid: errors.isEmpty, errors: errors)
  }

  /// Validates a document and throws the first error on failure.
  /// - Parameter document: The JSON document to validate.
  /// - Returns: `true` if valid.
  /// - Throws: `JSONSchemaError` — the first validation error.
  public func validates(_ document: JSON) throws -> Bool {
    let result = validate(document)
    if !result.valid, let first = result.errors.first {
      throw first
    }
    return result.valid
  }

  // MARK: - Core validation

  /// Validates a single value against a subschema, collecting errors.
  private func validateValue(
    _ value: JSON,
    against subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard subschema.isObject else {
      // Non-object schemas are treated as pass-through (no constraints)
      return
    }

    // Validate keywords in order
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
  }

  // MARK: - Keyword: type

  private func validateType(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
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
          instancePath: instancePath,
          schemaPath: schemaPath + "/type",
          keyword: "type",
          message: "type must be a string or array of strings"
        ))
      return
    }

    let actualType = typeNameOf(value)
    let isMatch: Bool
    if allowedTypes.contains(actualType) {
      isMatch = true
    } else if actualType == "integer" && allowedTypes.contains("number") {
      // integer is a subset of number
      isMatch = true
    } else {
      isMatch = false
    }

    if !isMatch {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/type",
          keyword: "type",
          message: "expected \(allowedTypes.joined(separator: ", ")) but found \(actualType)"
        ))
    }
  }

  /// Returns the JSON Schema type name for a JSON value.
  private func typeNameOf(_ value: JSON) -> String {
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

  private func validateProperties(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let properties = subschema["properties"], properties.isObject, value.isObject else {
      return
    }

    for (key, propSchema) in properties.objectValue ?? [:] {
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

  private func validateRequired(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let required = subschema["required"], required.isArray, value.isObject else { return }

    for reqElem in required {
      guard let key = reqElem.stringValue else {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/required",
            keyword: "required",
            message: "required array must contain strings"
          ))
        continue
      }

      if value[key] == nil || value[key]!.isNull {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/required",
            keyword: "required",
            message: "required property '\(key)' is missing or null"
          ))
      }
    }
  }

  // MARK: - Keyword: minimum

  private func validateMinimum(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let minVal = subschema["minimum"], let minDouble = minVal.floatValue else { return }
    guard let valDouble = value.floatValue else { return }

    if valDouble < minDouble {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/minimum",
          keyword: "minimum",
          message: "value \(valDouble) is less than minimum \(minDouble)"
        ))
    }
  }

  // MARK: - Keyword: maximum

  private func validateMaximum(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let maxVal = subschema["maximum"], let maxDouble = maxVal.floatValue else { return }
    guard let valDouble = value.floatValue else { return }

    if valDouble > maxDouble {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/maximum",
          keyword: "maximum",
          message: "value \(valDouble) is greater than maximum \(maxDouble)"
        ))
    }
  }

  // MARK: - Keyword: exclusiveMinimum

  private func validateExclusiveMinimum(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let exclMin = subschema["exclusiveMinimum"] else { return }

    if draft == .draft7 {
      // Draft 7: exclusiveMinimum is a boolean modifier on minimum
      guard let exclBool = exclMin.boolValue, let minVal = subschema["minimum"],
        let minDouble = minVal.floatValue
      else { return }
      guard let valDouble = value.floatValue else { return }
      if exclBool && valDouble <= minDouble {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/exclusiveMinimum",
            keyword: "exclusiveMinimum",
            message: "value \(valDouble) is less than or equal to minimum \(minDouble)"
          ))
      }
    } else {
      // Draft 2020-12: exclusiveMinimum is a number (exclusive bound)
      guard let exclDouble = exclMin.floatValue else { return }
      guard let valDouble = value.floatValue else { return }
      if valDouble <= exclDouble {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/exclusiveMinimum",
            keyword: "exclusiveMinimum",
            message: "value \(valDouble) is not strictly greater than \(exclDouble)"
          ))
      }
    }
  }

  // MARK: - Keyword: exclusiveMaximum

  private func validateExclusiveMaximum(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let exclMax = subschema["exclusiveMaximum"] else { return }

    if draft == .draft7 {
      // Draft 7: exclusiveMaximum is a boolean modifier on maximum
      guard let exclBool = exclMax.boolValue, let maxVal = subschema["maximum"],
        let maxDouble = maxVal.floatValue
      else { return }
      guard let valDouble = value.floatValue else { return }
      if exclBool && valDouble >= maxDouble {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/exclusiveMaximum",
            keyword: "exclusiveMaximum",
            message: "value \(valDouble) is greater than or equal to maximum \(maxDouble)"
          ))
      }
    } else {
      // Draft 2020-12: exclusiveMaximum is a number (exclusive bound)
      guard let exclDouble = exclMax.floatValue else { return }
      guard let valDouble = value.floatValue else { return }
      if valDouble >= exclDouble {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/exclusiveMaximum",
            keyword: "exclusiveMaximum",
            message: "value \(valDouble) is not strictly less than \(exclDouble)"
          ))
      }
    }
  }

  // MARK: - Keyword: multipleOf

  private func validateMultipleOf(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let multipleOf = subschema["multipleOf"], let mVal = multipleOf.floatValue, mVal > 0
    else { return }
    guard let valDouble = value.floatValue else { return }

    // Check divisibility
    let remainder = valDouble.truncatingRemainder(dividingBy: mVal)
    if remainder > 1e-12 && abs(remainder - mVal) > 1e-12 {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/multipleOf",
          keyword: "multipleOf",
          message: "value \(valDouble) is not a multiple of \(mVal)"
        ))
    }
  }

  // MARK: - Keyword: pattern

  private func validatePattern(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let patternStr = subschema["pattern"]?.stringValue else { return }
    guard let strVal = value.stringValue else { return }

    do {
      let regex = try NSRegularExpression(pattern: patternStr, options: [])
      let range = NSRange(strVal.startIndex..<strVal.endIndex, in: strVal)
      if regex.firstMatch(in: strVal, options: [], range: range) == nil {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/pattern",
            keyword: "pattern",
            message: "string '\(strVal)' does not match pattern '\(patternStr)'"
          ))
      }
    } catch {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/pattern",
          keyword: "pattern",
          message: "invalid regex pattern: \(patternStr)"
        ))
    }
  }

  // MARK: - Keyword: enum

  private func validateEnum(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let enumValues = subschema["enum"], enumValues.isArray else { return }

    var found = false
    for allowed in enumValues {
      if value == allowed {
        found = true
        break
      }
    }

    if !found {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/enum",
          keyword: "enum",
          message: "value does not match any of the allowed values in enum"
        ))
    }
  }

  // MARK: - Keyword: const

  private func validateConst(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let constVal = subschema["const"] else { return }

    if value != constVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/const",
          keyword: "const",
          message: "value does not match the const value"
        ))
    }
  }
}

// MARK: - Convenience accessors

extension JSON {
  /// Returns the `OrderedDictionary` backing if this value is an object.
  fileprivate var objectValue: OrderedDictionary<String, JSON>? {
    guard case .object(let dict) = storage else { return nil }
    return dict
  }
}
