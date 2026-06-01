import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Numeric Bounds

@Suite("JSONSchema numeric bounds")
struct JSONSchemaNumericBoundsTests {
  @Test("minimum — valid")
  func minimumValid() throws {
    let schema = try JSONSchema(
      schema: .object(["minimum": .number(.integer(10))])
    )
    #expect(schema.validating(.number(.integer(10))).valid)
    #expect(schema.validating(.number(.integer(20))).valid)
  }

  @Test("minimum — invalid")
  func minimumInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["minimum": .number(.integer(10))])
    )
    let result = schema.validating(.number(.integer(5)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .minimum)
  }

  @Test("maximum — valid")
  func maximumValid() throws {
    let schema = try JSONSchema(
      schema: .object(["maximum": .number(.integer(100))])
    )
    #expect(schema.validating(.number(.integer(50))).valid)
    #expect(schema.validating(.number(.integer(100))).valid)
  }

  @Test("maximum — invalid")
  func maximumInvalid() throws {
    let schema = try JSONSchema(
      schema: .object(["maximum": .number(.integer(100))])
    )
    let result = schema.validating(.number(.integer(200)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .maximum)
  }

  @Test("minimum + maximum — valid in range")
  func minMaxInRange() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minimum": .number(.integer(10)),
        "maximum": .number(.integer(100)),
      ])
    )
    #expect(schema.validating(.number(.integer(50))).valid)
  }

  @Test("minimum + maximum — invalid out of range")
  func minMaxOutOfRange() throws {
    let schema = try JSONSchema(
      schema: .object([
        "minimum": .number(.integer(10)),
        "maximum": .number(.integer(100)),
      ])
    )
    let result = schema.validating(.number(.integer(5)))
    #expect(!result.valid)
  }

  @Test("minimum with Int64.max preserves precision")
  func minInt64Max() throws {
    let schema = try JSONSchema(
      schema: .object(["minimum": .number(.integer(Int64.max))])
    )
    #expect(schema.validating(.number(.integer(Int64.max))).valid)
    let result = schema.validating(.number(.integer(Int64.max - 1)))
    #expect(!result.valid)
    #expect(result.errors.first?.keyword == .minimum)
  }
}
