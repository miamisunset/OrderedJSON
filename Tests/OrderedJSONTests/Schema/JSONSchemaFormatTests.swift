import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Format validation

@Test("format — date-time valid")
func formatDateTimeValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("date-time")]), draft: .draft7
  )
  #expect(schema.validating(.string("2025-01-01T12:00:00Z")).valid)
  #expect(schema.validating(.string("2025-01-01T12:00:00.123Z")).valid)
  #expect(schema.validating(.string("2025-01-01T12:00:00+05:30")).valid)
}

@Test("format — date-time invalid")
func formatDateTimeInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("date-time")]), draft: .draft7
  )
  #expect(!schema.validating(.string("2025-01-01 12:00:00")).valid)
  #expect(!schema.validating(.string("2025-01-01T12:00:00")).valid)  // no timezone
  #expect(!schema.validating(.string("not-a-date")).valid)
}

@Test("format — date valid")
func formatDateValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("date")]), draft: .draft7
  )
  #expect(schema.validating(.string("2025-01-01")).valid)
  #expect(schema.validating(.string("2025-12-31")).valid)
}

@Test("format — date invalid")
func formatDateInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("date")]), draft: .draft7
  )
  #expect(!schema.validating(.string("2025-13-01")).valid)  // invalid month
  #expect(!schema.validating(.string("not-a-date")).valid)
}

@Test("format — time valid")
func formatTimeValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("time")]), draft: .draft7
  )
  #expect(schema.validating(.string("12:00:00")).valid)
  #expect(schema.validating(.string("12:00:00Z")).valid)
  #expect(schema.validating(.string("12:00:00.123Z")).valid)
}

@Test("format — time invalid")
func formatTimeInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("time")]), draft: .draft7
  )
  #expect(!schema.validating(.string("25:00:00")).valid)  // invalid hour
  #expect(!schema.validating(.string("not-a-time")).valid)
}

@Test("format — duration valid")
func formatDurationValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("duration")]), draft: .draft7
  )
  #expect(schema.validating(.string("P1Y")).valid)
  #expect(schema.validating(.string("P1Y2M3DT4H5M6S")).valid)
  #expect(schema.validating(.string("PT1H")).valid)
}

@Test("format — duration invalid")
func formatDurationInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("duration")]), draft: .draft7
  )
  #expect(!schema.validating(.string("P")).valid)
  #expect(!schema.validating(.string("PT")).valid)
}

@Test("format — email valid")
func formatEmailValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("email")]), draft: .draft7
  )
  #expect(schema.validating(.string("user@example.com")).valid)
  #expect(schema.validating(.string("a.b@c.d")).valid)
}

@Test("format — email invalid")
func formatEmailInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("email")]), draft: .draft7
  )
  #expect(!schema.validating(.string("not-an-email")).valid)
  #expect(!schema.validating(.string("@example.com")).valid)
  #expect(!schema.validating(.string("user@example.")).valid)  // empty TLD
  #expect(!schema.validating(.string("user@.com")).valid)  // no domain
}

@Test("format — hostname valid")
func formatHostnameValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("hostname")]), draft: .draft7
  )
  #expect(schema.validating(.string("example.com")).valid)
  #expect(schema.validating(.string("my-host.example.com")).valid)
}

@Test("format — hostname invalid")
func formatHostnameInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("hostname")]), draft: .draft7
  )
  #expect(!schema.validating(.string("not_a_hostname")).valid)
}

@Test("format — hostname single-label")
func formatHostnameSingleLabel() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("hostname")]), draft: .draft7
  )
  #expect(schema.validating(.string("localhost")).valid)
  #expect(schema.validating(.string("myhost")).valid)
}

@Test("format — ipv4 valid")
func formatIPv4Valid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("ipv4")]), draft: .draft7
  )
  #expect(schema.validating(.string("192.168.1.1")).valid)
  #expect(schema.validating(.string("127.0.0.1")).valid)
}

@Test("format — ipv4 invalid")
func formatIPv4Invalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("ipv4")]), draft: .draft7
  )
  #expect(!schema.validating(.string("300.0.0.0")).valid)
  #expect(!schema.validating(.string("not-an-ip")).valid)
}

@Test("format — ipv6 valid")
func formatIPv6Valid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("ipv6")]), draft: .draft7
  )
  #expect(schema.validating(.string("::1")).valid)
  #expect(schema.validating(.string("fe80::1")).valid)
}

@Test("format — ipv6 invalid")
func formatIPv6Invalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("ipv6")]), draft: .draft7
  )
  #expect(!schema.validating(.string("not-an-ipv6")).valid)
}

@Test("format — uuid valid")
func formatUUIDValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("uuid")]), draft: .draft7
  )
  #expect(schema.validating(.string("f47ac10b-58cc-4372-a567-0e02b2c3d479")).valid)
}

@Test("format — uuid invalid")
func formatUUIDInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("uuid")]), draft: .draft7
  )
  #expect(!schema.validating(.string("not-a-uuid")).valid)
}

@Test("format — uri valid")
func formatURIValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("uri")]), draft: .draft7
  )
  #expect(schema.validating(.string("https://example.com")).valid)
  #expect(schema.validating(.string("https://example.com/path")).valid)
  #expect(schema.validating(.string("ftp://ftp.example.com")).valid)
}

@Test("format — uri invalid")
func formatURIInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("uri")]), draft: .draft7
  )
  #expect(!schema.validating(.string("/relative/path")).valid)  // no scheme
  #expect(!schema.validating(.string("not-a-uri")).valid)
}

@Test("format — uri-reference valid")
func formatURIReferenceValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("uri-reference")]), draft: .draft7
  )
  #expect(schema.validating(.string("/relative/path")).valid)
  #expect(schema.validating(.string("#fragment")).valid)
  #expect(schema.validating(.string("https://example.com")).valid)
}

@Test("format — uri-reference invalid")
func formatURIReferenceInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("uri-reference")]), draft: .draft7
  )
  #expect(!schema.validating(.string("")).valid)  // empty string is not a valid URI
}

@Test("format — json-pointer valid")
func formatJSONPointerValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("json-pointer")]), draft: .draft7
  )
  #expect(schema.validating(.string("")).valid)  // root
  #expect(schema.validating(.string("/foo/bar")).valid)
}

@Test("format — json-pointer invalid")
func formatJSONPointerInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("json-pointer")]), draft: .draft7
  )
  #expect(!schema.validating(.string("no-leading-slash")).valid)
}

@Test("format — regex valid")
func formatRegexValid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("regex")]), draft: .draft7
  )
  #expect(schema.validating(.string("^[a-z]+$")).valid)
}

@Test("format — regex invalid")
func formatRegexInvalid() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("regex")]), draft: .draft7
  )
  #expect(!schema.validating(.string("[invalid")).valid)
}

@Test("format — non-string skips validation")
func formatNonString() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("email")]), draft: .draft7
  )
  #expect(schema.validating(.number(.integer(42))).valid)
  #expect(schema.validating(.object([:])).valid)
}

@Test("format — unknown format skips validation")
func formatUnknown() throws {
  let schema = try JSONSchema(
    schema: .object(["format": .string("nonexistent-format")]), draft: .draft7
  )
  #expect(schema.validating(.string("anything")).valid)
}

@Test("format — draft202012 annotation mode (no assertion)")
func formatDraft202012Annotation() throws {
  // In Draft 2020-12, format is an annotation — it should NOT produce errors.
  // Default draft (auto) resolves to draft202012 when no $schema is present.
  let schema = try JSONSchema(
    schema: .object(["format": .string("email")])
  )
  #expect(schema.validating(.string("not-an-email")).valid)
}

@Test("format — draft7 assertion mode")
func formatDraft7Assertion() throws {
  // In Draft 7, format is an assertion — it SHOULD produce errors
  let schema = try JSONSchema(
    schema: .object(["format": .string("email")]), draft: .draft7
  )
  // Invalid emails should fail validation in assertion mode
  #expect(!schema.validating(.string("not-an-email")).valid)
}

@Test("format — disabled format skips validation")
func formatDisabled() throws {
  var opts = JSONSchemaFormatOptions()
  opts.disable(.email)
  let schema = try JSONSchema(
    schema: .object(["format": .string("email")]), draft: .draft7, formatOptions: opts
  )
  #expect(schema.validating(.string("not-an-email")).valid)
}

@Test("format — format keyword absent skips")
func formatAbsent() throws {
  let schema = try JSONSchema(schema: .object([:]))
  #expect(schema.validating(.string("anything")).valid)
}

// MARK: - Format Edge Cases

@Suite("JSONSchema format edge cases")
struct JSONSchemaFormatEdgeCasesTests {
  @Test("format — date invalid day combinations")
  func formatDateInvalidDays() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("date")]), draft: .draft7
    )
    #expect(!schema.validating(.string("2025-02-30")).valid)
    #expect(!schema.validating(.string("2025-04-31")).valid)
    #expect(!schema.validating(.string("2025-02-29")).valid)
    #expect(schema.validating(.string("2024-02-29")).valid)
  }

  @Test("format — time invalid values")
  func formatTimeInvalidValues() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("time")]), draft: .draft7
    )
    #expect(!schema.validating(.string("24:00:00")).valid)
    #expect(!schema.validating(.string("12:60:00")).valid)
    #expect(!schema.validating(.string("12:00:60")).valid)
  }

  @Test("format — uuid with missing dashes")
  func formatUUIDMissingDashes() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("uuid")]), draft: .draft7
    )
    #expect(!schema.validating(.string("f47ac10b58cc4372a5670e02b2c3d479")).valid)
  }

  @Test("format — ipv4 with leading zeros")
  func formatIPv4LeadingZeros() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("ipv4")]), draft: .draft7
    )
    #expect(schema.validating(.string("192.168.001.001")).valid)
  }

  @Test("format — date-time with fractional seconds no timezone")
  func formatDateTimeFractionalNoTZ() throws {
    let schema = try JSONSchema(
      schema: .object(["format": .string("date-time")]), draft: .draft7
    )
    #expect(!schema.validating(.string("2025-01-01T12:00:00.123")).valid)
  }
}
