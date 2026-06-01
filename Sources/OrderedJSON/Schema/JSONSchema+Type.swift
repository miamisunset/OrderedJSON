import Foundation
import OrderedCollections

extension JSONSchema {

  // MARK: - Keyword: type

  /// Validates the `type` keyword — checks that the value's type matches one
  /// of the allowed types. Integers are allowed for `number` type.
  func validateType(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let typeSpec = subschema[key: .type] else { return }
    let allowedTypes: [String]
    if typeSpec.isString {
      allowedTypes = [typeSpec.stringValue!]
    } else if typeSpec.isArray {
      allowedTypes = typeSpec.compactMap { $0.stringValue }
    } else {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/type", keyword: .type,
          message: "type must be a string or array of strings"
        )
      )
      return
    }
    let actualType = typeNameOf(value)
    let isMatch =
      allowedTypes.contains(actualType)
      || (actualType == "integer" && allowedTypes.contains("number"))
    if !isMatch {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/type", keyword: .type,
          message: "expected \(allowedTypes.joined(separator: ", ")) but found \(actualType)"
        )
      )
    }
  }

  /// Returns the JSON type name for a value (e.g., "string", "integer").
  /// Per JSON Schema, a float with zero fractional part (e.g. 1.0) is an integer.
  func typeNameOf(_ value: JSON) -> String {
    switch value.storage {
    case .null: return "null"
    case .boolean: return "boolean"
    case .number(.integer): return "integer"
    case .number(.float):
      guard let d = value.doubleValue else { return "number" }
      if d == d.rounded(.towardZero) && d.isFinite { return "integer" }
      return "number"
    case .string: return "string"
    case .object: return "object"
    case .array: return "array"
    }
  }
}
