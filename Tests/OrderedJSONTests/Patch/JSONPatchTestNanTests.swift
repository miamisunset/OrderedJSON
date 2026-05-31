import Testing

@testable import OrderedJSON

@Suite("JSONPatch test NaN tests")
struct JSONPatchTestNanTests {
  @Test("test with NaN fails (NaN != NaN per IEEE 754)") func testNaN() {
    let json = JSON.number(.float(Double.nan))
    let patch = JSON.array([
      JSON.object([
        "op": .string("test"),
        "path": .string(""),
        "value": JSON.number(.float(Double.nan)),
      ])
    ])
    let error = #expect(throws: JSONError.self) { try json.applying(patch) }
    #expect(error == .formatError("Test failed: value mismatch"))
  }

  @Test("test with regular number passes") func testRegularNumber() throws {
    let json = JSON.number(.float(1.5))
    let patch = JSON.array([
      JSON.object([
        "op": .string("test"),
        "path": .string(""),
        "value": JSON.number(.float(1.5)),
      ])
    ])
    let result = try json.applying(patch)
    #expect(result == json)
  }
}
