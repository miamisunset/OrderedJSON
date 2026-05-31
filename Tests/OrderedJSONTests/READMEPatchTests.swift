import Testing

@testable import OrderedJSON

@Test func readmeJSONPatch() throws {
  let source = try JSON.parse(
    """
    {"a": 1, "b": 2}
    """)

  let patch = try JSON.parse(
    """
    [{"op": "add",     "path": "/c", "value": 3},
     {"op": "remove",  "path": "/b"},
     {"op": "replace", "path": "/a", "value": 99}]
    """)

  // Non-mutating — applying()
  let patched = try source.applying(patch)
  #expect(patched["a"] == JSON(99))
  #expect(patched["c"] == JSON(3))
  #expect(patched["b"] == nil)

  // Mutating — patch()
  var mutable = source
  try mutable.patch(patch)
  #expect(mutable["a"] == JSON(99))
  #expect(mutable["c"] == JSON(3))
  #expect(mutable["b"] == nil)
}

@Test func readmeDiff() throws {
  let source = try JSON.parse(
    """
    {"a": 1, "b": 2}
    """)
  let target = try JSON.parse(
    """
    {"a": 1, "c": 3}
    """)

  let diff = JSON.diff(source, target)
  #expect(diff.isArray)
}

@Test func readmeMergePatch() throws {
  let source = try JSON.parse(
    """
    {"a": 1, "b": {"c": 2, "d": 3}}
    """)

  let patch = try JSON.parse(
    """
    {"a": null, "b": {"c": 99}}
    """)

  let merged = source.mergePatch(patch)
  #expect(merged["b"]?["c"] == JSON(99))
}
