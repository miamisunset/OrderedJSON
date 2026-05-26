import Foundation
import OrderedCollections

/// A compiled JSON Schema that can validate JSON documents against a schema.
public struct JSONSchema: Hashable, Sendable {
  public enum Draft: Hashable, Sendable {
    case draft7
    case draft202012
    case auto
  }

  internal let schemaJSON: JSON
  internal let draft: Draft

  public init(schema: JSON, draft: Draft = .auto) throws {
    let resolvedDraft: Draft
    if draft == .auto {
      resolvedDraft = JSONSchema.detectDraft(from: schema)
    } else {
      resolvedDraft = draft
    }

    guard schema.isObject || schema.isBoolean else {
      throw JSONSchemaError(
        instancePath: "",
        schemaPath: "",
        keyword: "schema",
        message: "Schema must be a JSON object or boolean"
      )
    }

    if schema.isObject {
      try JSONSchema.validatePatterns(schema)
    }

    self.schemaJSON = schema
    self.draft = resolvedDraft
  }

  // MARK: - Draft detection

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

  internal static func detectDraft(from schema: JSON) -> Draft {
    guard let schemaStr = schema["$schema"]?.stringValue else { return .draft202012 }
    if draft7URIs.contains(schemaStr) { return .draft7 }
    if draft6URIs.contains(schemaStr) { return .draft202012 }
    if draft202012URIs.contains(schemaStr) { return .draft202012 }
    if schemaStr.contains("draft-07") || schemaStr.contains("draft-7") { return .draft7 }
    if schemaStr.contains("2020-12") || schemaStr.contains("draft/2020-12") { return .draft202012 }
    return .draft202012
  }

  // MARK: - Validation API

  public func validate(_ document: JSON) throws -> Bool {
    var errors: [JSONSchemaError] = []
    validateValue(document, against: schemaJSON, instancePath: "", schemaPath: "", errors: &errors)
    if let first = errors.first { throw first }
    return true
  }

  public func validation(of document: JSON) -> JSONSchemaResult {
    var errors: [JSONSchemaError] = []
    validateValue(document, against: schemaJSON, instancePath: "", schemaPath: "", errors: &errors)
    return JSONSchemaResult(valid: errors.isEmpty, errors: errors)
  }

  public func isValid(_ document: JSON) -> Bool {
    var errors: [JSONSchemaError] = []
    validateValue(document, against: schemaJSON, instancePath: "", schemaPath: "", errors: &errors)
    return errors.isEmpty
  }

  // MARK: - Core validation (dispatches to all keyword validators)

  internal func validateValue(
    _ value: JSON,
    against subschema: JSON,
    instancePath: String,
    schemaPath: String,
    errors: inout [JSONSchemaError]
  ) {
    if let boolVal = subschema.boolValue {
      if !boolVal {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath, keyword: "false",
            message: "boolean schema false rejects the value"))
      }
      return
    }
    guard subschema.isObject else { return }

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
    validateMinLength(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
    validateMaxLength(
      value, subschema: subschema, instancePath: instancePath, schemaPath: schemaPath,
      errors: &errors)
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

  // MARK: - Schema-aware equality

  internal static func schemaEqual(_ lhs: JSON, _ rhs: JSON) -> Bool {
    switch (lhs.storage, rhs.storage) {
    case (.null, .null): return true
    case (.boolean(let a), .boolean(let b)): return a == b
    case (.number(.integer(let a)), .number(.integer(let b))): return a == b
    case (.number(.float(let a)), .number(.float(let b))): return a == b
    case (.number(.integer(let a)), .number(.float(let b))): return Double(a) == b
    case (.number(.float(let a)), .number(.integer(let b))): return a == Double(b)
    case (.string(let a), .string(let b)): return a == b
    case (.array(let a), .array(let b)):
      guard a.count == b.count else { return false }
      for (i, elem) in a.enumerated() { if !schemaEqual(elem, b[i]) { return false } }
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
}
