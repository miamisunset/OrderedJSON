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

    self.schemaJSON = schema
    self.draft = resolvedDraft
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

  // MARK: - Pattern pre-compilation

  /// Validates all `pattern` keyword regexes in a schema at init time.
  /// - Parameter schema: The schema JSON to scan.
  /// - Throws: `JSONSchemaError` if any pattern contains invalid regex syntax.
  internal static func validatePatterns(_ schema: JSON) throws {
    guard schema.isObject else { return }

    // Check direct pattern keyword
    if let patternStr = schema["pattern"]?.stringValue {
      do {
        let _ = try NSRegularExpression(pattern: patternStr, options: [])
      } catch {
        throw JSONSchemaError(
          instancePath: "",
          schemaPath: "/pattern",
          keyword: "pattern",
          message: "invalid regex pattern: \(patternStr)"
        )
      }
    }

    // Recursively check properties sub-schemas
    if let properties = schema["properties"], properties.isObject {
      guard case .object(let dict) = properties.storage else { return }
      for (_, propSchema) in dict {
        try JSONSchema.validatePatterns(propSchema)
      }
    }

    // Recursively check items / prefixItems
    if let items = schema["items"], items.isObject {
      try JSONSchema.validatePatterns(items)
    }
    if let prefixItems = schema["prefixItems"], prefixItems.isArray {
      for item in prefixItems where item.isObject {
        try JSONSchema.validatePatterns(item)
      }
    }

    // Recursively check composition keywords
    for keyword in ["allOf", "anyOf", "oneOf"] {
      if let subschemas = schema[keyword], subschemas.isArray {
        for sub in subschemas where sub.isObject {
          try JSONSchema.validatePatterns(sub)
        }
      }
    }
    if let notSchema = schema["not"], notSchema.isObject {
      try JSONSchema.validatePatterns(notSchema)
    }
    if let ifSchema = schema["if"], ifSchema.isObject {
      try JSONSchema.validatePatterns(ifSchema)
    }
    if let thenSchema = schema["then"], thenSchema.isObject {
      try JSONSchema.validatePatterns(thenSchema)
    }
    if let elseSchema = schema["else"], elseSchema.isObject {
      try JSONSchema.validatePatterns(elseSchema)
    }

    // Check $defs
    if let defs = schema["$defs"], defs.isObject {
      guard case .object(let dict) = defs.storage else { return }
      for (_, defSchema) in dict {
        try JSONSchema.validatePatterns(defSchema)
      }
    }
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
      errors: &errors)
    if let first = errors.first {
      throw first
    }
    return true
  }

  /// Validates a JSON document against this schema and returns a result
  /// containing **all** validation errors (if any). Does **not** throw.
  ///
  /// Use this when you need to inspect every error rather than fail-fast.
  ///
  /// - Parameter document: The JSON document to validate.
  /// - Returns: A `JSONSchemaResult` with all errors collected.
  public func validation(of document: JSON) -> JSONSchemaResult {
    var errors: [JSONSchemaError] = []
    validateValue(
      document, against: schemaJSON, instancePath: "", schemaPath: "",
      errors: &errors)
    return JSONSchemaResult(valid: errors.isEmpty, errors: errors)
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
      errors: &errors)
    return errors.isEmpty
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
    // Handle boolean schemas (Draft 2020-12): true accepts everything,
    // false rejects everything.
    if let boolVal = subschema.boolValue {
      if !boolVal {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath,
            keyword: "false",
            message: "boolean schema false rejects the value"
          ))
      }
      return
    }

    guard subschema.isObject else { return }

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

    // String length keywords
    validateMinLength(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateMaxLength(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)

    // Composition keywords
    validateAllOf(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateAnyOf(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateOneOf(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateNot(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateIfThenElse(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateDependentSchemas(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateDependentRequired(
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

      // Per JSON Schema spec, `required` checks only key *presence*.
      // An explicit `null` value satisfies required.
      if value[key] == nil {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/required",
            keyword: "required",
            message: "required property '\(key)' is missing"
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
    guard let minVal = subschema["minimum"] else { return }
    guard let valDouble = value.floatValue else { return }
    guard let minDouble = minVal.floatValue else { return }

    // Fast path: both are integers — compare as Int64 to preserve precision
    if let valInt = value.intValue, let minInt = minVal.intValue {
      if valInt < minInt {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/minimum",
            keyword: "minimum",
            message: "value \(valInt) is less than minimum \(minInt)"
          ))
      }
      return
    }

    // Fall back to Double comparison
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
    guard let maxVal = subschema["maximum"] else { return }
    guard let valDouble = value.floatValue else { return }
    guard let maxDouble = maxVal.floatValue else { return }

    // Fast path: both are integers — compare as Int64 to preserve precision
    if let valInt = value.intValue, let maxInt = maxVal.intValue {
      if valInt > maxInt {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/maximum",
            keyword: "maximum",
            message: "value \(valInt) is greater than maximum \(maxInt)"
          ))
      }
      return
    }

    // Fall back to Double comparison
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
      guard let exclBool = exclMin.boolValue, let minVal = subschema["minimum"] else { return }
      guard let valDouble = value.floatValue else { return }
      guard let minDouble = minVal.floatValue else { return }

      if exclBool {
        // Fast path: both integers
        if let valInt = value.intValue, let minInt = minVal.intValue {
          if valInt <= minInt {
            errors.append(
              JSONSchemaError(
                instancePath: instancePath,
                schemaPath: schemaPath + "/exclusiveMinimum",
                keyword: "exclusiveMinimum",
                message:
                  "value \(valInt) is less than or equal to minimum \(minInt)"
              ))
          }
          return
        }
        if valDouble <= minDouble {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath,
              schemaPath: schemaPath + "/exclusiveMinimum",
              keyword: "exclusiveMinimum",
              message:
                "value \(valDouble) is less than or equal to minimum \(minDouble)"
            ))
        }
      }
    } else {
      // Draft 2020-12: exclusiveMinimum is a number (exclusive bound)
      guard let exclDouble = exclMin.floatValue else { return }
      guard let valDouble = value.floatValue else { return }

      // Fast path: both integers
      if let valInt = value.intValue, let exclInt = exclMin.intValue {
        if valInt <= exclInt {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath,
              schemaPath: schemaPath + "/exclusiveMinimum",
              keyword: "exclusiveMinimum",
              message:
                "value \(valInt) is not strictly greater than \(exclInt)"
            ))
        }
        return
      }

      if valDouble <= exclDouble {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/exclusiveMinimum",
            keyword: "exclusiveMinimum",
            message:
              "value \(valDouble) is not strictly greater than \(exclDouble)"
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
      guard let exclBool = exclMax.boolValue, let maxVal = subschema["maximum"] else { return }
      guard let valDouble = value.floatValue else { return }
      guard let maxDouble = maxVal.floatValue else { return }

      if exclBool {
        // Fast path: both integers
        if let valInt = value.intValue, let maxInt = maxVal.intValue {
          if valInt >= maxInt {
            errors.append(
              JSONSchemaError(
                instancePath: instancePath,
                schemaPath: schemaPath + "/exclusiveMaximum",
                keyword: "exclusiveMaximum",
                message:
                  "value \(valInt) is greater than or equal to maximum \(maxInt)"
              ))
          }
          return
        }
        if valDouble >= maxDouble {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath,
              schemaPath: schemaPath + "/exclusiveMaximum",
              keyword: "exclusiveMaximum",
              message:
                "value \(valDouble) is greater than or equal to maximum \(maxDouble)"
            ))
        }
      }
    } else {
      // Draft 2020-12: exclusiveMaximum is a number (exclusive bound)
      guard let exclDouble = exclMax.floatValue else { return }
      guard let valDouble = value.floatValue else { return }

      // Fast path: both integers
      if let valInt = value.intValue, let exclInt = exclMax.intValue {
        if valInt >= exclInt {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath,
              schemaPath: schemaPath + "/exclusiveMaximum",
              keyword: "exclusiveMaximum",
              message:
                "value \(valInt) is not strictly less than \(exclInt)"
            ))
        }
        return
      }

      if valDouble >= exclDouble {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/exclusiveMaximum",
            keyword: "exclusiveMaximum",
            message:
              "value \(valDouble) is not strictly less than \(exclDouble)"
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

    // Fast path: both are integers — use integer modulo (no epsilon needed)
    if let valInt = value.intValue, let mInt = multipleOf.intValue {
      if valInt % mInt != 0 {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: schemaPath + "/multipleOf",
            keyword: "multipleOf",
            message: "value \(valInt) is not a multiple of \(mInt)"
          ))
      }
      return
    }

    // Float path: use Double with scaled epsilon
    guard let valDouble = value.floatValue else { return }
    let remainder = valDouble.truncatingRemainder(dividingBy: mVal)
    // Scale epsilon by the divisor to handle large doubles correctly
    let epsilon = max(1e-12 * mVal, 1e-12)
    if remainder > epsilon && abs(remainder - mVal) > epsilon {
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

    // Regex syntax was validated at init time; re-compile here for matching.
    // TODO: Cache NSRegularExpression instances for performance (Phase 4/10).
    guard let regex = try? NSRegularExpression(pattern: patternStr, options: []) else {
      return
    }

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
      if JSONSchema.schemaEqual(value, allowed) {
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

    if !JSONSchema.schemaEqual(value, constVal) {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/const",
          keyword: "const",
          message: "value does not match the const value"
        ))
    }
  }

  // MARK: - Keyword: minLength / maxLength

  private func validateMinLength(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let minLen = subschema["minLength"], let minLenVal = minLen.intValue else { return }
    guard let strVal = value.stringValue else { return }

    if strVal.count < minLenVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/minLength",
          keyword: "minLength",
          message: "string length \(strVal.count) is less than minimum \(minLenVal)"
        ))
    }
  }

  private func validateMaxLength(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let maxLen = subschema["maxLength"], let maxLenVal = maxLen.intValue else { return }
    guard let strVal = value.stringValue else { return }

    if strVal.count > maxLenVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/maxLength",
          keyword: "maxLength",
          message: "string length \(strVal.count) is greater than maximum \(maxLenVal)"
        ))
    }
  }

  // MARK: - Composition keywords

  private func validateAllOf(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let allOf = subschema["allOf"], allOf.isArray else { return }

    for (index, sub) in allOf.enumerated() {
      let subSchemaPath = schemaPath + "/allOf/" + String(index)
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath,
        schemaPath: subSchemaPath, errors: &subErrors)
      if let firstError = subErrors.first {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath,
            schemaPath: subSchemaPath,
            keyword: "allOf",
            message: "subschema #\(index) failed: \(firstError.message)"
          ))
      }
    }
  }

  private func validateAnyOf(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let anyOf = subschema["anyOf"], anyOf.isArray else { return }

    var matched = false
    for (_, sub) in anyOf.enumerated() {
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath,
        schemaPath: schemaPath, errors: &subErrors)
      if subErrors.isEmpty {
        matched = true
        break
      }
    }

    if !matched {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/anyOf",
          keyword: "anyOf",
          message: "value does not match any subschema in anyOf"
        ))
    }
  }

  private func validateOneOf(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let oneOf = subschema["oneOf"], oneOf.isArray else { return }

    var matchCount = 0
    for (_, sub) in oneOf.enumerated() {
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath,
        schemaPath: schemaPath, errors: &subErrors)
      if subErrors.isEmpty {
        matchCount += 1
      }
    }

    if matchCount != 1 {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/oneOf",
          keyword: "oneOf",
          message: "value matches \(matchCount) subschemas in oneOf (expected exactly 1)"
        ))
    }
  }

  private func validateNot(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let notSchema = subschema["not"], notSchema.isObject else { return }

    var subErrors: [JSONSchemaError] = []
    validateValue(
      value, against: notSchema, instancePath: instancePath,
      schemaPath: schemaPath + "/not", errors: &subErrors)

    if subErrors.isEmpty {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath,
          schemaPath: schemaPath + "/not",
          keyword: "not",
          message: "value matches the not schema"
        ))
    }
  }

  private func validateIfThenElse(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let ifSchema = subschema["if"] else { return }

    // Evaluate the if schema
    var ifErrors: [JSONSchemaError] = []
    validateValue(
      value, against: ifSchema, instancePath: instancePath,
      schemaPath: schemaPath + "/if", errors: &ifErrors)

    let ifValid = ifErrors.isEmpty

    if ifValid {
      // if validates → then must validate (if present)
      if let thenSchema = subschema["then"] {
        var thenErrors: [JSONSchemaError] = []
        validateValue(
          value, against: thenSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/then", errors: &thenErrors)
        if let firstError = thenErrors.first {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath,
              schemaPath: schemaPath + "/then",
              keyword: "then",
              message: "then schema failed: \(firstError.message)"
            ))
        }
      }
    } else {
      // if fails → else must validate (if present)
      if let elseSchema = subschema["else"] {
        var elseErrors: [JSONSchemaError] = []
        validateValue(
          value, against: elseSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/else", errors: &elseErrors)
        if let firstError = elseErrors.first {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath,
              schemaPath: schemaPath + "/else",
              keyword: "else",
              message: "else schema failed: \(firstError.message)"
            ))
        }
      }
    }
  }

  private func validateDependentSchemas(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let depSchemas = subschema["dependentSchemas"], depSchemas.isObject else { return }
    guard value.isObject else { return }

    guard case .object(let depDict) = depSchemas.storage else { return }
    for (key, depSchema) in depDict {
      // When key is present in the instance, validate the instance against depSchema
      if value[key] != nil {
        var subErrors: [JSONSchemaError] = []
        validateValue(
          value, against: depSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/dependentSchemas/" + key, errors: &subErrors)
        if let firstError = subErrors.first {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath,
              schemaPath: schemaPath + "/dependentSchemas/" + key,
              keyword: "dependentSchemas",
              message: "dependent schema for key '\(key)' failed: \(firstError.message)"
            ))
        }
      }
    }
  }

  private func validateDependentRequired(
    _ value: JSON,
    subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    guard let depRequired = subschema["dependentRequired"], depRequired.isObject else { return }
    guard value.isObject else { return }

    guard case .object(let depDict) = depRequired.storage else { return }
    for (key, requiredArray) in depDict {
      guard let requiredKeys = requiredArray.arrayValue else { continue }
      // When key is present in the instance, the listed keys must also be present
      if value[key] != nil {
        for reqKey in requiredKeys {
          guard let reqKeyStr = reqKey.stringValue else { continue }
          if value[reqKeyStr] == nil {
            errors.append(
              JSONSchemaError(
                instancePath: instancePath,
                schemaPath: schemaPath + "/dependentRequired/" + key,
                keyword: "dependentRequired",
                message: "key '\(key)' requires key '\(reqKeyStr)'"
              ))
          }
        }
      }
    }
  }

  // MARK: - Schema-aware equality

  /// Compares two JSON values using JSON Schema semantics for `enum`/`const`.
  ///
  /// Differences from `JSON.==`:
  /// - Numeric: `.integer(1)` == `.float(1.0)` — spec says they are equal
  /// - Object: key-value pairs are compared ignoring order
  ///
  /// - Parameters:
  ///   - lhs: First JSON value.
  ///   - rhs: Second JSON value.
  /// - Returns: `true` if the values are equal under JSON Schema semantics.
  internal static func schemaEqual(_ lhs: JSON, _ rhs: JSON) -> Bool {
    switch (lhs.storage, rhs.storage) {
    case (.null, .null):
      return true
    case (.boolean(let a), .boolean(let b)):
      return a == b
    case (.number(.integer(let a)), .number(.integer(let b))):
      return a == b
    case (.number(.float(let a)), .number(.float(let b))):
      return a == b
    case (.number(.integer(let a)), .number(.float(let b))):
      // Integer vs float: compare as Double (spec: 1 == 1.0)
      return Double(a) == b
    case (.number(.float(let a)), .number(.integer(let b))):
      return a == Double(b)
    case (.string(let a), .string(let b)):
      return a == b
    case (.array(let a), .array(let b)):
      // Compare element-wise using schemaEqual for deep numeric equality
      guard a.count == b.count else { return false }
      for (i, elem) in a.enumerated() {
        if !schemaEqual(elem, b[i]) { return false }
      }
      return true
    case (.object(let a), .object(let b)):
      // Objects: compare key-value pairs ignoring order
      guard a.count == b.count else { return false }
      for (key, value) in a {
        guard let bVal = b[key] else { return false }
        if !schemaEqual(value, bVal) { return false }
      }
      return true
    default:
      return false
    }
  }
}
