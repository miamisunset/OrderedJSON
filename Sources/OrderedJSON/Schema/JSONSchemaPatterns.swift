import Foundation
import OrderedCollections

extension JSONSchema {
    /// Validates all `pattern` keyword regexes in a schema at init time.
    /// Recursively visits every subschema that could contain a `pattern`.
    /// - Parameter schema: The schema JSON to scan.
    /// - Throws: `JSONSchemaError` if any pattern contains invalid regex syntax.
    static func validatePatterns(_ schema: JSON) throws {
        guard schema.isObject else { return }

        // Check direct pattern keyword
        if let patternStr = schema["pattern"]?.stringValue {
            do {
                _ = try NSRegularExpression(pattern: patternStr, options: [])
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
            guard case let .object(dict) = properties.storage else { return }
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

        // Check patternProperties keys are valid regexes, and recurse into schemas
        if let pp = schema["patternProperties"], pp.isObject {
            guard case let .object(patternDict) = pp.storage else { return }
            for (pattern, _) in patternDict {
                do {
                    _ = try NSRegularExpression(pattern: pattern, options: [])
                } catch {
                    throw JSONSchemaError(
                        instancePath: "",
                        schemaPath: "/patternProperties",
                        keyword: "patternProperties",
                        message: "invalid regex pattern '\(pattern)' in patternProperties"
                    )
                }
            }
            for (_, patternSchema) in patternDict {
                try JSONSchema.validatePatterns(patternSchema)
            }
        }

        // Recursively check contains
        if let containsSchema = schema["contains"], containsSchema.isObject {
            try JSONSchema.validatePatterns(containsSchema)
        }

        // Recursively check additionalProperties / unevaluatedProperties
        if let ap = schema["additionalProperties"], ap.isObject {
            try JSONSchema.validatePatterns(ap)
        }
        if let up = schema["unevaluatedProperties"], up.isObject {
            try JSONSchema.validatePatterns(up)
        }

        // Recursively check additionalItems / unevaluatedItems
        if let ai = schema["additionalItems"], ai.isObject {
            try JSONSchema.validatePatterns(ai)
        }
        if let ui = schema["unevaluatedItems"], ui.isObject {
            try JSONSchema.validatePatterns(ui)
        }

        // Recursively check propertyNames
        if let pn = schema["propertyNames"], pn.isObject {
            try JSONSchema.validatePatterns(pn)
        }

        // Recursively check dependentSchemas values
        if let depSchemas = schema["dependentSchemas"], depSchemas.isObject {
            guard case let .object(depDict) = depSchemas.storage else { return }
            for (_, depSchema) in depDict {
                try JSONSchema.validatePatterns(depSchema)
            }
        }

        // Check $defs
        if let defs = schema["$defs"], defs.isObject {
            guard case let .object(dict) = defs.storage else { return }
            for (_, defSchema) in dict {
                try JSONSchema.validatePatterns(defSchema)
            }
        }
    }
}
