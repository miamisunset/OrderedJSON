import Foundation
import OrderedCollections

extension JSONSchema {

  // MARK: - Keyword: properties

  /// Validates the `properties` keyword — validates each property value
  /// against its corresponding subschema. Non-object values are skipped.
  func validateProperties(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let properties = subschema[key: .properties], properties.isObject, value.isObject else {
      return
    }
    guard case .object(let dict) = properties.storage else { return }
    for (key, propSchema) in dict {
      let childSchemaPath = schemaPath + "/properties/" + key
      if let childValue = value[key] {
        validateValue(
          childValue, against: propSchema,
          instancePath: instancePath.isEmpty ? key : instancePath + "/" + key,
          schemaPath: childSchemaPath, errors: &errors, ctx: ctx
        )
      }
    }
  }

  // MARK: - Keyword: required

  /// Validates the `required` keyword — checks that all required property
  /// keys are present (presence only, not null-rejecting).
  func validateRequired(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let required = subschema[key: .required], required.isArray, value.isObject else { return }
    for reqElem in required {
      guard let key = reqElem.stringValue else {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/required", keyword: .required,
            message: "required array must contain strings"
          )
        )
        continue
      }
      if value[key] == nil {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/required", keyword: .required,
            message: "required property '\(key)' is missing"
          )
        )
      }
    }
  }
}
