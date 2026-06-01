import Foundation
import OrderedCollections

extension JSONSchema {

  // MARK: - Array keywords (shared)

  /// Validates `minItems` — checks that the array has at least the
  /// specified number of items.
  func validateMinItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let minVal = subschema[key: .minItems]?.intValue, let arr = value.arrayValue else { return }
    if arr.count < minVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/minItems", keyword: "minItems",
          message: "array length \(arr.count) is less than minimum \(minVal)"
        )
      )
    }
  }

  /// Validates `maxItems` — checks that the array has at most the
  /// specified number of items.
  func validateMaxItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let maxVal = subschema[key: .maxItems]?.intValue, let arr = value.arrayValue else { return }
    if arr.count > maxVal {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/maxItems", keyword: "maxItems",
          message: "array length \(arr.count) is greater than maximum \(maxVal)"
        )
      )
    }
  }

  /// Validates `uniqueItems` — checks that all items in the array are
  /// unique (using schema-aware equality).
  func validateUniqueItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard subschema[key: .uniqueItems]?.boolValue == true, let arr = value.arrayValue else { return }
    for i in 0..<arr.count {
      for j in (i + 1)..<arr.count {
        if JSONSchema.schemaEqual(arr[i], arr[j]) {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/uniqueItems",
              keyword: "uniqueItems",
              message: "items at indexes \(i) and \(j) are equal"
            )
          )
          return
        }
      }
    }
  }

  /// Validates `contains` — checks that at least one item in the array
  /// matches the subschema.
  func validateContains(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let containsSchema = subschema[key: .contains], let arr = value.arrayValue else { return }
    // When minContains is 0, contains imposes no constraint (Draft 2020-12).
    // The `contains` keyword itself only requires at least 1 match; minContains
    // is handled by validateMinContains.
    let minContains = subschema[key: .minContains]?.intValue
    if let minC = minContains, minC == 0 { return }
    for item in arr {
      var itemErrors: [JSONSchemaError] = []
      validateValue(
        item, against: containsSchema, instancePath: instancePath,
        schemaPath: schemaPath + "/contains", errors: &itemErrors, ctx: ctx
      )
      if itemErrors.isEmpty { return }
    }
    errors.append(
      JSONSchemaError(
        instancePath: instancePath, schemaPath: schemaPath + "/contains", keyword: "contains",
        message: "array does not contain at least one item matching the subschema"
      )
    )
  }
}
