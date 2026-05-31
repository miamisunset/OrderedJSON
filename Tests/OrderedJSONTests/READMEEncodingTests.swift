import Testing

@testable import OrderedJSON

@Test func readmeEncodingSerialization() {
  let value = JSON.object([
    "name": JSON.string("Bob"),
    "age": JSON.number(.integer(25)),
  ])

  let compact = value.dump()
  #expect(compact == "{\"name\":\"Bob\",\"age\":25}")

  let pretty = value.dump(indent: 2)
  #expect(pretty.contains("\n"))
  #expect(pretty.contains("  "))
}
