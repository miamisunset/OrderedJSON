import Foundation
import Testing

@testable import OrderedJSON

@Suite("Integration: patch → re-parse")
struct JSONIntegrationPatchTests {
  @Test("patch → dump → parse: add operation round-trip")
  func patchDumpParseAdd() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2}"#)
    let patch = try JSON.parse(
      #"""
      [{"op": "add", "path": "/c", "value": 3}]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["a"] == JSON(1))
    #expect(reparsed["c"] == JSON(3))
  }

  @Test("patch → dump → parse: remove operation round-trip")
  func patchDumpParseRemove() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2, "c": 3}"#)
    let patch = try JSON.parse(
      #"""
      [{"op": "remove", "path": "/b"}]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["b"] == nil)
  }

  @Test("patch → dump → parse: replace operation round-trip")
  func patchDumpParseReplace() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2}"#)
    let patch = try JSON.parse(
      #"""
      [{"op": "replace", "path": "/a", "value": 99}]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["a"] == JSON(99))
  }

  @Test("patch → dump → parse: move operation round-trip")
  func patchDumpParseMove() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2}"#)
    let patch = try JSON.parse(
      #"""
      [{"op": "move", "from": "/a", "path": "/c"}]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["a"] == nil)
    #expect(reparsed["c"] == JSON(1))
  }

  @Test("patch → dump → parse: copy operation round-trip")
  func patchDumpParseCopy() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2}"#)
    let patch = try JSON.parse(
      #"""
      [{"op": "copy", "from": "/a", "path": "/copy_of_a"}]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["a"] == JSON(1))
    #expect(reparsed["copy_of_a"] == JSON(1))
  }

  @Test("patch → dump → parse: multi-operation patch round-trip")
  func patchDumpParseMultiOp() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2, "c": 3}"#)
    let patch = try JSON.parse(
      #"""
      [
        {"op": "remove", "path": "/b"},
        {"op": "add", "path": "/d", "value": 4},
        {"op": "replace", "path": "/a", "value": 99}
      ]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["a"] == JSON(99))
    #expect(reparsed["b"] == nil)
    #expect(reparsed["d"] == JSON(4))
  }

  @Test("patch → dump → parse: array operations round-trip")
  func patchDumpParseArrayOps() throws {
    let source = try JSON.parse(#"{"arr": [1, 2, 3]}"#)
    let patch = try JSON.parse(
      #"""
      [
        {"op": "add", "path": "/arr/-", "value": 4},
        {"op": "remove", "path": "/arr/0"}
      ]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["arr"]?.count == 3)
    #expect(reparsed["arr"]?[2] == JSON(4))
  }

  @Test("patch → dump → parse: nested path operations round-trip")
  func patchDumpParseNested() throws {
    let source = try JSON.parse(
      #"""
      {"nested": {"x": 1, "y": 2}}
      """#)
    let patch = try JSON.parse(
      #"""
      [
        {"op": "add", "path": "/nested/z", "value": 3},
        {"op": "replace", "path": "/nested/x", "value": 99}
      ]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["nested"]?["x"] == JSON(99))
    #expect(reparsed["nested"]?["z"] == JSON(3))
  }

  @Test("diff → apply → dump → parse: diff round-trip")
  func diffApplyDumpParse() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2}"#)
    let target = try JSON.parse(#"{"a": 1, "c": 3}"#)

    let diff = JSON.diff(source, target)
    let patched = try source.applying(diff)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed == target)
  }
}
