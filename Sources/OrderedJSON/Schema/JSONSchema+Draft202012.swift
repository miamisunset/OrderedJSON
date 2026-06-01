import Foundation
import OrderedCollections

extension JSONSchema {

  // ======================================================================
  // MARK: - Draft 2020-12 specific validators
  // ======================================================================

  // MARK: - Keyword: dependentSchemas

  /// Validates the `dependentSchemas` keyword — when a property key is
  /// present, the entire object must validate against the dependent schema.
  /// Draft 2020-12 only (Draft 7 uses `dependencies`).
  func validateDependentSchemas(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let depSchemas = subschema[key: .dependentSchemas], depSchemas.isObject, value.isObject
    else {
      return
    }
    guard case .object(let depDict) = depSchemas.storage else { return }
    for (key, depSchema) in depDict {
      guard value[key] != nil else { continue }
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: depSchema, instancePath: instancePath,
        schemaPath: schemaPath + "/dependentSchemas/" + key, errors: &subErrors, ctx: ctx
      )
      if let first = subErrors.first {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/dependentSchemas/" + key,
            keyword: .dependentSchemas,
            message: "dependent schema for key '\(key)' failed: \(first.message)"
          )
        )
      }
    }
  }

  // MARK: - Keyword: dependentRequired

  /// Validates the `dependentRequired` keyword — when a property key is
  /// present, other specified property keys must also be present.
  /// Draft 2020-12 only (Draft 7 uses `dependencies`).
  func validateDependentRequired(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let depRequired = subschema[key: .dependentRequired], depRequired.isObject, value.isObject
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
                keyword: .dependentRequired, message: "key '\(key)' requires key '\(reqKeyStr)'"
              )
            )
          }
        }
      }
    }
  }

  // MARK: - Keyword: prefixItems

  /// Validates `prefixItems` (Draft 2020-12) — tuple validation for the
  /// first N items. Each schema validates the corresponding item index.
  func validatePrefixItems(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let prefixItems = subschema[key: .prefixItems], prefixItems.isArray,
      let arr = value.arrayValue
    else { return }
    let schemas = prefixItems.arrayValue ?? []
    for (index, item) in arr.prefix(schemas.count).enumerated() {
      validateValue(
        item, against: schemas[index],
        instancePath: instancePath.isEmpty ? String(index) : instancePath + "/" + String(index),
        schemaPath: schemaPath + "/prefixItems/" + String(index), errors: &errors, ctx: ctx
      )
    }
  }

  // MARK: - Keyword: items (schema mode)

  /// Validates `items` as a schema (Draft 2020-12) — applies to items
  /// beyond `prefixItems`. In Draft 7, `items` schema applies to all items
  /// (handled by the shared `validateItemsSchema` call when prefixItems is absent).
  func validateItemsSchema(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let items = subschema[key: .items], let arr = value.arrayValue else { return }
    let prefixCount: Int
    if let prefixItems = subschema[key: .prefixItems], prefixItems.isArray {
      prefixCount = prefixItems.arrayValue?.count ?? 0
    } else {
      prefixCount = 0
    }
    let remaining = arr.dropFirst(prefixCount)
    if items.isObject {
      for (index, item) in remaining.enumerated() {
        let actualIndex = index + prefixCount
        validateValue(
          item, against: items,
          instancePath: instancePath.isEmpty
            ? String(actualIndex) : instancePath + "/" + String(actualIndex),
          schemaPath: schemaPath + "/items", errors: &errors, ctx: ctx
        )
      }
    } else if let boolVal = items.boolValue {
      if !boolVal {
        for (index, item) in remaining.enumerated() {
          let actualIndex = index + prefixCount
          validateValue(
            item, against: items,
            instancePath: instancePath.isEmpty
              ? String(actualIndex) : instancePath + "/" + String(actualIndex),
            schemaPath: schemaPath + "/items", errors: &errors, ctx: ctx
          )
        }
      }
      // If items is true, all remaining items pass (no validation needed)
    }
  }
}
