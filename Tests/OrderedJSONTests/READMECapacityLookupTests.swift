import Testing

@testable import OrderedJSON

@Test func readmeCapacityLookup() throws {
  let json = try JSON.parse(
    """
    {"a": 1, "b": 2, "c": 3}
    """)

  #expect(json.count == 3)
  #expect(json.isEmpty == false)

  #expect(json.first == JSON.number(.integer(1)))
  #expect(json.last == JSON.number(.integer(3)))

  #expect(json.contains(key: "b"))
  #expect(json.find(key: "b") == JSON.number(.integer(2)))
  #expect(json.find(key: "missing") == nil)

  let arr = JSON.array([
    .string("a"),
    .number(.integer(1)),
    .boolean(true),
  ])
  #expect(arr.contains(element: .string("a")))
  #expect(!arr.contains(element: .string("z")))
}
