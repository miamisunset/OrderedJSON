import Testing

@testable import OrderedJSON

@Test func readmeArrayBuilder() {
  let items = JSON.ArrayBuilder()
    .add("a")
    .add(42)
    .add(true)
    .add(3.14)
    .build()
  #expect(items.isArray)
  #expect(items.count == 4)
}

@Test func readmeArrayBuilderNested() {
  let mixed = JSON.ArrayBuilder()
    .add("outer")
    .add(
      JSON.ObjectBuilder()
        .set("x", 1)
        .build()
    )
    .add(
      JSON.ArrayBuilder()
        .add("inner")
        .add(99)
        .build()
    )
    .build()
  #expect(mixed.isArray)
  #expect(mixed.count == 3)
}
