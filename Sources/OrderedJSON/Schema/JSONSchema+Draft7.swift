import Foundation
import OrderedCollections

extension JSONSchema {

  // ======================================================================
  // MARK: - Draft 7 specific validators
  // ======================================================================

  // MARK: - Keyword: exclusiveMinimum (Draft 7 boolean modifier)

  /// Validates `exclusiveMinimum` as a boolean modifier on `minimum`
  /// (Draft 7 semantics). Ignored when the value is numeric.
  func validateExclusiveMinimumBool(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let exclBool = subschema[key: .exclusiveMinimum]?.boolValue,
      let minVal = subschema[key: .minimum],
      let valDouble = value.doubleValue, let minDouble = minVal.doubleValue
    else { return }
    if exclBool {
      if let valInt = value.intValue, let minInt = minVal.intValue {
        if valInt <= minInt {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMinimum",
              keyword: "exclusiveMinimum",
              message: "value \(valInt) is less than or equal to minimum \(minInt)"
            )
          )
        }
        return
      }
      if valDouble <= minDouble {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMinimum",
            keyword: "exclusiveMinimum",
            message: "value \(valDouble) is less than or equal to minimum \(minDouble)"
          )
        )
      }
    }
  }

  // MARK: - Keyword: exclusiveMaximum (Draft 7 boolean modifier)

  /// Validates `exclusiveMaximum` as a boolean modifier on `maximum`
  /// (Draft 7 semantics). Ignored when the value is numeric.
  func validateExclusiveMaximumBool(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let exclBool = subschema[key: .exclusiveMaximum]?.boolValue,
      let maxVal = subschema[key: .maximum],
      let valDouble = value.doubleValue, let maxDouble = maxVal.doubleValue
    else { return }
    if exclBool {
      if let valInt = value.intValue, let maxInt = maxVal.intValue {
        if valInt >= maxInt {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMaximum",
              keyword: "exclusiveMaximum",
              message: "value \(valInt) is greater than or equal to maximum \(maxInt)"
            )
          )
        }
        return
      }
      if valDouble >= maxDouble {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMaximum",
            keyword: "exclusiveMaximum",
            message: "value \(valDouble) is greater than or equal to maximum \(maxDouble)"
          )
        )
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
  func validateFormat(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let formatStr = subschema[key: .format]?.stringValue, let strVal = value.stringValue else {
      return
    }
    guard let format = JSONSchemaFormat(rawValue: formatStr) else { return }
    guard formatOptions.isEnabled(format) else { return }
    if !format.validate(strVal) {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/format", keyword: "format",
          message: "string '\(strVal)' does not match format '\(formatStr)'"
        )
      )
    }
  }

  // MARK: - Keyword: dependencies (Draft 7)

  /// Validates the `dependencies` keyword (Draft 7) — when a property key
  /// is present, the dependency is either a schema (object) or a required
  /// array (array of strings). Each entry in the object triggers either
  /// schema validation or required-key checking based on its type.
  ///
  /// Draft 2020-12 splits this into `dependentSchemas` + `dependentRequired`.
  func validateDependencies(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let deps = subschema[key: .dependencies], deps.isObject, value.isObject else { return }
    guard case .object(let depDict) = deps.storage else { return }
    for (key, depValue) in depDict {
      guard value[key] != nil else { continue }
      if depValue.isObject {
        var subErrors: [JSONSchemaError] = []
        validateValue(
          value, against: depValue, instancePath: instancePath,
          schemaPath: schemaPath + "/dependencies/" + key, errors: &subErrors, ctx: ctx
        )
        if let first = subErrors.first {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/dependencies/" + key,
              keyword: "dependencies",
              message: "dependency for key '\(key)' failed: \(first.message)"
            )
          )
        }
      } else if depValue.isArray {
        for reqKey in depValue.arrayValue ?? [] {
          guard let reqKeyStr = reqKey.stringValue else { continue }
          if value[reqKeyStr] == nil {
            errors.append(
              JSONSchemaError(
                instancePath: instancePath, schemaPath: schemaPath + "/dependencies/" + key,
                keyword: "dependencies",
                message: "key '\(key)' requires key '\(reqKeyStr)'"
              )
            )
          }
        }
      } else if let boolVal = depValue.boolValue, !boolVal {
        // Boolean false dependency — the key exists but value is false
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/dependencies/" + key,
            keyword: "dependencies",
            message: "dependency '\(key)' is false, but key exists"
          )
        )
      }
    }
  }

  // MARK: - Keyword: additionalItems (Draft 7 tuple mode)

  /// Validates `additionalItems` (Draft 7 only) — schema for items beyond
  /// the tuple length defined by `items` (when items is an array).
  /// When `items` is a schema (not array), `additionalItems` is ignored
  /// because `items` already applies to all items.
  func validateAdditionalItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let additionalItems = subschema[key: .additionalItems], let arr = value.arrayValue else {
      return
    }
    guard let items = subschema[key: .items], items.isArray else { return }
    let tupleCount = items.arrayValue?.count ?? 0
    for (index, item) in arr.enumerated() {
      if index < tupleCount { continue }
      validateValue(
        item, against: additionalItems,
        instancePath: instancePath.isEmpty ? String(index) : instancePath + "/" + String(index),
        schemaPath: schemaPath + "/additionalItems", errors: &errors, ctx: ctx
      )
    }
  }

  // MARK: - Keyword: items tuple mode (Draft 7 array)

  /// Validates `items` as a tuple array (Draft 7) — validates the first N
  /// items against the corresponding schemas in the array.
  func validateItemsTuple(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let items = subschema[key: .items], items.isArray, let arr = value.arrayValue else { return }
    let tupleSchemas = items.arrayValue ?? []
    for (index, item) in arr.prefix(tupleSchemas.count).enumerated() {
      validateValue(
        item, against: tupleSchemas[index],
        instancePath: instancePath.isEmpty ? String(index) : instancePath + "/" + String(index),
        schemaPath: schemaPath + "/items/" + String(index), errors: &errors, ctx: ctx
      )
    }
  }
}
