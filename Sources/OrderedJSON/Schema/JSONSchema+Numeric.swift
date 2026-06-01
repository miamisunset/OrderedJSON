import Foundation
import OrderedCollections

extension JSONSchema {

  // MARK: - Keyword: minimum

  /// Validates the `minimum` keyword — checks that the numeric value is >= minimum.
  func validateMinimum(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let minVal = subschema[key: .minimum] else { return }
    let valInt = value.intValue
    let minInt = minVal.intValue
    if let v = valInt, let m = minInt {
      if v < m {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/minimum", keyword: "minimum",
            message: "value \(v) is less than minimum \(m)"
          )
        )
      }
      return
    }
    guard let v = value.doubleValue, let m = minVal.doubleValue, v < m else { return }
    errors.append(
      JSONSchemaError(
        instancePath: instancePath, schemaPath: schemaPath + "/minimum", keyword: "minimum",
        message: "value \(v) is less than minimum \(m)"
      )
    )
  }

  // MARK: - Keyword: maximum

  /// Validates the `maximum` keyword — checks that the numeric value is <= maximum.
  func validateMaximum(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let maxVal = subschema[key: .maximum] else { return }
    let valInt = value.intValue
    let maxInt = maxVal.intValue
    if let v = valInt, let m = maxInt {
      if v > m {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/maximum", keyword: "maximum",
            message: "value \(v) is greater than maximum \(m)"
          )
        )
      }
      return
    }
    guard let v = value.doubleValue, let m = maxVal.doubleValue, v > m else { return }
    errors.append(
      JSONSchemaError(
        instancePath: instancePath, schemaPath: schemaPath + "/maximum", keyword: "maximum",
        message: "value \(v) is greater than maximum \(m)"
      )
    )
  }

  // MARK: - Keyword: exclusiveMinimum (numeric bound — shared)

  /// Validates `exclusiveMinimum` as a numeric bound (Draft 2020-12 semantics).
  /// Also used in Draft 7 when the value is numeric (not a boolean modifier on `minimum`).
  func validateExclusiveMinimum(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let exclMin = subschema[key: .exclusiveMinimum], exclMin.isNumber else { return }
    guard let exclDouble = exclMin.doubleValue, let valDouble = value.doubleValue else { return }
    if let valInt = value.intValue, let exclInt = exclMin.intValue {
      if valInt <= exclInt {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMinimum",
            keyword: "exclusiveMinimum",
            message: "value \(valInt) is not strictly greater than \(exclInt)"
          )
        )
      }
      return
    }
    if valDouble <= exclDouble {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMinimum",
          keyword: "exclusiveMinimum",
          message: "value \(valDouble) is not strictly greater than \(exclDouble)"
        )
      )
    }
  }

  // MARK: - Keyword: exclusiveMaximum (numeric bound — shared)

  /// Validates `exclusiveMaximum` as a numeric bound (Draft 2020-12 semantics).
  /// Also used in Draft 7 when the value is numeric (not a boolean modifier on `maximum`).
  func validateExclusiveMaximum(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let exclMax = subschema[key: .exclusiveMaximum], exclMax.isNumber else { return }
    guard let exclDouble = exclMax.doubleValue, let valDouble = value.doubleValue else { return }
    if let valInt = value.intValue, let exclInt = exclMax.intValue {
      if valInt >= exclInt {
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMaximum",
            keyword: "exclusiveMaximum",
            message: "value \(valInt) is not strictly less than \(exclInt)"
          )
        )
      }
      return
    }
    if valDouble >= exclDouble {
      errors.append(
        JSONSchemaError(
          instancePath: instancePath, schemaPath: schemaPath + "/exclusiveMaximum",
          keyword: "exclusiveMaximum",
          message: "value \(valDouble) is not strictly less than \(exclDouble)"
        )
      )
    }
  }

  // MARK: - Keyword: multipleOf

  /// Validates the `multipleOf` keyword — checks that the numeric value
  /// is a multiple of the given divisor. Zero and negative divisors are
  /// ignored per spec. Uses division-based check to avoid float precision
  /// issues with large values and tiny divisors.
  func validateMultipleOf(
    _ value: JSON, subschema: JSON, instancePath: String, schemaPath: String,
    errors: inout [JSONSchemaError], ctx _: EvaluationContext
  ) {
    guard let mVal = subschema[key: .multipleOf] else { return }
    if let mInt = mVal.intValue {
      if let valInt = value.intValue {
        if mInt > 0, valInt % mInt != 0 {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/multipleOf",
              keyword: "multipleOf", message: "\(valInt) is not a multiple of \(mInt)"
            )
          )
        }
        return
      }
    }
    guard let mDouble = mVal.doubleValue, let valDouble = value.doubleValue else { return }
    if mDouble > 0 {
      let ratio = valDouble / mDouble
      if !ratio.isFinite {
        // Division overflowed — the value cannot be an exact multiple
        errors.append(
          JSONSchemaError(
            instancePath: instancePath, schemaPath: schemaPath + "/multipleOf",
            keyword: "multipleOf", message: "\(valDouble) is not a multiple of \(mDouble)"
          )
        )
      } else {
        let rounded = ratio.rounded(.towardZero)
        let diff = abs(ratio - rounded)
        let epsilon = max(1e-12 * ratio, 1e-12)
        if diff > epsilon {
          errors.append(
            JSONSchemaError(
              instancePath: instancePath, schemaPath: schemaPath + "/multipleOf",
              keyword: "multipleOf", message: "\(valDouble) is not a multiple of \(mDouble)"
            )
          )
        }
      }
    }
  }
}
