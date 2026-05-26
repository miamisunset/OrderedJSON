import Foundation
import OrderedCollections

extension JSONSchema {

  /// Validates all `pattern` keyword regexes in a schema at init time.
  /// Recursively visits every subschema that could contain a `pattern`.
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

    // Recursively check dependentSchemas values
    if let depSchemas = schema["dependentSchemas"], depSchemas.isObject {
      guard case .object(let depDict) = depSchemas.storage else { return }
      for (_, depSchema) in depDict {
        try JSONSchema.validatePatterns(depSchema)
      }
    }

    // Check $defs
    if let defs = schema["$defs"], defs.isObject {
      guard case .object(let dict) = defs.storage else { return }
      for (_, defSchema) in dict {
        try JSONSchema.validatePatterns(defSchema)
      }
    }
  }
}
