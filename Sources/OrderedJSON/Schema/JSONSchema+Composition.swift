import Foundation
import OrderedCollections

extension JSONSchema {

  // MARK: - Composition: allOf

  /// Validates the `allOf` keyword — checks that the value matches all
  /// subschemas. Errors from each failing subschema are collected.
  func validateAllOf(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let allOf = subschema[key: .allOf], allOf.isArray else { return }
    for (index, sub) in allOf.enumerated() {
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath,
        schemaPath: schemaPath + "/allOf/" + String(index), errors: &subErrors, ctx: ctx
      )
      if let first = subErrors.first {
        errors.append(
          JSONSchemaError(
            instancePath: first.instancePath.isEmpty ? instancePath : first.instancePath,
            schemaPath: schemaPath + "/allOf/" + String(index), keyword: .allOf,
            message: "subschema #\(index) failed: \(first.message)"
          )
        )
        // Short-circuit: allOf must pass all, so stop after first failure.
        break
      }
    }
  }

  // MARK: - Composition: anyOf

  /// Validates the `anyOf` keyword — checks that the value matches at least
  /// one subschema. Empty arrays always fail.
  ///
  /// Short-circuits (breaks) after the first matching subschema — this
  /// optimization is correct per spec: anyOf succeeds as soon as one
  /// subschema matches.
  func validateAnyOf(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let anyOf = subschema[key: .anyOf], anyOf.isArray else { return }
    var matched = false
    for sub in anyOf {
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath,
        schemaPath: schemaPath, errors: &subErrors, ctx: ctx
      )
      if subErrors.isEmpty {
        matched = true
        break
      }
    }
    if !matched {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/anyOf", keyword: .anyOf,
          message: "value does not match any subschema in anyOf"
        )
      )
    }
  }

  // MARK: - Composition: oneOf

  /// Validates the `oneOf` keyword — checks that the value matches exactly
  /// one subschema. Early exits on the second match.
  ///
  /// Short-circuits (breaks) after the second matching subschema — this
  /// optimization is correct per spec: oneOf fails as soon as two
  /// subschemas match.
  func validateOneOf(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let oneOf = subschema[key: .oneOf], oneOf.isArray else { return }
    var matchCount = 0
    for sub in oneOf {
      var subErrors: [JSONSchemaError] = []
      validateValue(
        value, against: sub, instancePath: instancePath,
        schemaPath: schemaPath, errors: &subErrors, ctx: ctx
      )
      if subErrors.isEmpty { matchCount += 1 }
      if matchCount > 1 { break }
    }
    if matchCount != 1 {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/oneOf", keyword: .oneOf,
          message: "value matches \(matchCount) subschemas in oneOf (expected exactly 1)"
        )
      )
    }
  }

  // MARK: - Composition: not

  /// Validates the `not` keyword — checks that the value does NOT match
  /// the subschema. Boolean subschemas are supported.
  func validateNot(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard subschema[key: .not] != nil else { return }
    var subErrors: [JSONSchemaError] = []
    validateValue(
      value, against: subschema[key: .not]!, instancePath: instancePath,
      schemaPath: schemaPath + "/not", errors: &subErrors, ctx: ctx
    )
    if subErrors.isEmpty {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/not", keyword: .not,
          message: "value matches the not schema"
        )
      )
    }
  }

  // MARK: - Composition: if/then/else

  /// Validates the `if`/`then`/`else` keywords — if the `if` subschema
  /// matches, `then` must also match; if `if` fails, `else` must match.
  /// Missing `then`/`else` are skipped per spec.
  func validateIfThenElse(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx: EvaluationContext
  ) {
    guard let ifSchema = subschema[key: .if] else { return }
    var ifErrors: [JSONSchemaError] = []
    validateValue(
      value, against: ifSchema, instancePath: instancePath,
      schemaPath: schemaPath + "/if", errors: &ifErrors, ctx: ctx
    )
    if ifErrors.isEmpty {
      if let thenSchema = subschema[key: .then] {
        var thenErrors: [JSONSchemaError] = []
        validateValue(
          value, against: thenSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/then", errors: &thenErrors, ctx: ctx
        )
        if let first = thenErrors.first {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/then", keyword: .then,
              message: "then schema failed: \(first.message)"
            )
          )
        }
      }
    } else {
      if let elseSchema = subschema[key: .else] {
        var elseErrors: [JSONSchemaError] = []
        validateValue(
          value, against: elseSchema, instancePath: instancePath,
          schemaPath: schemaPath + "/else", errors: &elseErrors, ctx: ctx
        )
        if let first = elseErrors.first {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/else", keyword: .else,
              message: "else schema failed: \(first.message)"
            )
          )
        }
      }
    }
  }
}
