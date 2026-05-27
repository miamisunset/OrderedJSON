import OrderedCollections
@testable import OrderedJSON
import Testing

/// Tests for JSON Schema generation from JSON instances (Phase 9).
@Suite("JSON Schema generation tests") struct JSONSchemaGenerationTests {
    // MARK: - Primitive types

    @Test("null value generates type: null schema")
    func testNull() throws {
        let j: JSON = .null
        let schema = try j.schema()
        let result = schema.validation(of: j)
        #expect(result.valid)
        // Verify the generated schema
        let schemaJSON = JSONSchemaGeneration.generate(from: j)
        #expect(schemaJSON == .object(["type": .string("null")]))
    }

    @Test("boolean value generates type: boolean schema")
    func testBoolean() throws {
        let j: JSON = .boolean(true)
        let schema = try j.schema()
        #expect(schema.validation(of: j).valid)
        #expect(schema.validation(of: .boolean(false)).valid)

        let schemaJSON = JSONSchemaGeneration.generate(from: j)
        #expect(schemaJSON == .object(["type": .string("boolean")]))
    }

    @Test("integer value generates type: integer schema")
    func testInteger() throws {
        let j: JSON = .number(.integer(42))
        let schema = try j.schema()
        #expect(schema.validation(of: j).valid)
        #expect(schema.validation(of: .number(.integer(0))).valid)
        #expect(schema.validation(of: .number(.float(1.5))).valid == false) // float not integer
        // But integer schema accepts any integer
        let schemaJSON = JSONSchemaGeneration.generate(from: j)
        #expect(schemaJSON == .object(["type": .string("integer")]))
    }

    @Test("float value generates type: number schema")
    func testFloat() throws {
        let j: JSON = .number(.float(3.14))
        let schema = try j.schema()
        #expect(schema.validation(of: j).valid)
        #expect(schema.validation(of: .number(.float(0.0))).valid)
        #expect(schema.validation(of: .number(.integer(10))).valid) // integer is also number
        // But number schema accepts both float and integer
        let schemaJSON = JSONSchemaGeneration.generate(from: j)
        #expect(schemaJSON == .object(["type": .string("number")]))
    }

    @Test("string value generates type: string schema")
    func testString() throws {
        let j: JSON = .string("hello")
        let schema = try j.schema()
        #expect(schema.validation(of: j).valid)
        #expect(schema.validation(of: .string("world")).valid)

        let schemaJSON = JSONSchemaGeneration.generate(from: j)
        #expect(schemaJSON == .object(["type": .string("string")]))
    }

    // MARK: - Array

    @Test("empty array generates type: array with items: any")
    func emptyArray() throws {
        let j: JSON = .array([])
        let schema = try j.schema()
        #expect(schema.validation(of: j).valid)
        // Empty array should accept any array
        #expect(schema.validation(of: .array([.string("a")])).valid)
        #expect(schema.validation(of: .array([.number(.integer(1))])).valid)

        let schemaJSON = JSONSchemaGeneration.generate(from: j)
        #expect(schemaJSON["type"] == .string("array"))
        #expect(schemaJSON["items"] == .boolean(true))
    }

    @Test("homogeneous array generates items schema matching element type")
    func homogeneousArray() throws {
        let j: JSON = .array([.number(.integer(1)), .number(.integer(2)), .number(.integer(3))])
        let schema = try j.schema()
        #expect(schema.validation(of: j).valid)
        #expect(schema.validation(of: .array([.number(.integer(4))])).valid)
        #expect(schema.validation(of: .array([.string("x")])).valid == false) // wrong type

        let schemaJSON = JSONSchemaGeneration.generate(from: j)
        #expect(schemaJSON["type"] == .string("array"))
        #expect(schemaJSON["items"] == .object(["type": .string("integer")]))
    }

    @Test("heterogeneous array generates prefixItems with items: false")
    func heterogeneousArray() throws {
        let j: JSON = .array([.number(.integer(1)), .string("two"), .boolean(true)])
        let schema = try j.schema()
        #expect(schema.validation(of: j).valid)

        // A shorter array that matches the first prefix items should be valid
        #expect(schema.validation(of: .array([.number(.integer(1)), .string("two")])).valid)
        // An array with extra items beyond prefixItems should fail (items: false)
        #expect(
            schema.validation(
                of: .array([.number(.integer(1)), .string("two"), .boolean(true), .number(.integer(99))])
            ).valid == false
        )

        let schemaJSON = JSONSchemaGeneration.generate(from: j)
        #expect(schemaJSON["type"] == .string("array"))
        #expect(schemaJSON["prefixItems"]?.arrayValue?.count == 3)
        #expect(schemaJSON["items"] == .boolean(false))
    }

    // MARK: - Object

    @Test("object generates properties and required array")
    func testObject() throws {
        let dict: OrderedDictionary<String, JSON> = [
            "name": .string("Alice"),
            "age": .number(.integer(30)),
        ]
        let j: JSON = .object(dict)
        let schema = try j.schema()
        #expect(schema.validation(of: j).valid)

        // Missing required key should fail
        let partial: JSON = .object(["name": .string("Bob")])
        #expect(schema.validation(of: partial).valid == false)

        // Extra key should fail (since additionalProperties not allowed)
        let extra: JSON = .object([
            "name": .string("Alice"),
            "age": .number(.integer(30)),
            "extra": .string("bad"),
        ])
        #expect(schema.validation(of: extra).valid == false)

        let schemaJSON = JSONSchemaGeneration.generate(from: j)
        #expect(schemaJSON["type"] == .string("object"))
        #expect(schemaJSON["properties"]?.objectValue?.keys == ["name", "age"])
        #expect(schemaJSON["required"]?.arrayValue?.count == 2)
        #expect(schemaJSON["additionalProperties"] == .boolean(false))
    }

    @Test("object with null value generates null type property")
    func objectWithNullValue() throws {
        let dict: OrderedDictionary<String, JSON> = [
            "data": .null,
        ]
        let j: JSON = .object(dict)
        let schema = try j.schema()
        #expect(schema.validation(of: j).valid)

        let schemaJSON = JSONSchemaGeneration.generate(from: j)
        #expect(schemaJSON["type"] == .string("object"))
        #expect(schemaJSON["properties"]?["data"] == .object(["type": .string("null")]))
    }

    @Test("object with array values generates nested array schema")
    func objectWithArrayValues() throws {
        let dict: OrderedDictionary<String, JSON> = [
            "list": .array([.number(.integer(1)), .number(.integer(2))]),
        ]
        let j: JSON = .object(dict)
        let schema = try j.schema()
        #expect(schema.validation(of: j).valid)

        let schemaJSON = JSONSchemaGeneration.generate(from: j)
        #expect(schemaJSON["type"] == .string("object"))
        let props = schemaJSON["properties"]?.objectValue
        #expect(props?["list"]?["type"] == .string("array"))
        #expect(props?["list"]?["items"]?["type"] == .string("integer"))
    }

    // MARK: - Round-trip

    @Test("round-trip: generated schema validates original document")
    func roundTrip() throws {
        // Generate a schema from a document, then validate that document
        let doc: JSON = .object([
            "id": .number(.integer(1)),
            "title": .string("Hello"),
            "tags": .array([.string("swift"), .string("json")]),
            "metadata": .object(["version": .number(.float(1.0))]),
        ])

        let schema = try doc.schema()
        let result = schema.validation(of: doc)
        #expect(result.valid)
        #expect(result.errors.isEmpty)
    }

    @Test("nested object generates nested properties with required")
    func nestedObject() throws {
        let nested: JSON = .object([
            "outer": .object([
                "inner": .string("value"),
            ]),
        ])
        let schema = try nested.schema()
        #expect(schema.validation(of: nested).valid)

        // Should reject missing inner
        let missingInner: JSON = .object([
            "outer": .object([:]),
        ])
        #expect(schema.validation(of: missingInner).valid == false)
    }
}
