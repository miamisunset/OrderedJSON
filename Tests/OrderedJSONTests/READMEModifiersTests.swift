import Testing

@testable import OrderedJSON

@Test func readmeModifiers() throws {
  var json = try JSON.parse(
    """
    {"a": 1, "b": 2}
    """)

  json.clear()
  #expect(json.count == 0)

  json["a"] = JSON(10)
  #expect(json["a"] == JSON(10))

  json.remove(key: "a")
  #expect(json.count == 0)

  var arr = JSON.array([JSON(1), JSON(2), JSON(3)])
  arr.append(JSON(4))
  #expect(arr.count == 4)
  #expect(arr.last == JSON(4))

  arr.insert(JSON(0), at: 0)
  #expect(arr.count == 5)
  #expect(arr.first == JSON(0))

  arr.append(JSON(5))
  #expect(arr.last == JSON(5))

  var obj = JSON.object(["x": JSON(1)])
  obj.setDefault(key: "y", JSON(2))
  #expect(obj.count == 2)
  obj.setDefault(key: "x", JSON(99))
  #expect(obj["x"] == JSON(1))

  obj.update(with: JSON.object(["y": JSON(3), "z": JSON(4)]))
  #expect(obj.count == 3)
  #expect(obj["y"] == JSON(3))

  var config = JSON.object([
    "app": JSON.object(["theme": JSON.string("dark"), "lang": JSON.string("en")])
  ])
  let patch = JSON.object([
    "app": JSON.object(["lang": JSON.string("fr")])
  ])
  config.update(with: patch, mergingNested: true)
  #expect(config["app"]?["theme"] == JSON.string("dark"))
  #expect(config["app"]?["lang"] == JSON.string("fr"))

  var a = JSON(1)
  var b = JSON(2)
  a.swap(with: &b)
  #expect(a == JSON(2))
  #expect(b == JSON(1))
}
