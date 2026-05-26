import Testing
import Foundation
import OrderedCollections

@testable import OrderedJSON

// MARK: - Test suite runner

/// Runs the official JSON Schema Test Suite against our implementation.
@Test("JSON Schema Test Suite — Draft 2020-12")
func runDraft202012Suite() throws {
  try runTestSuite(draftDir: "draft2020-12", draft: .draft202012)
}

@Test("JSON Schema Test Suite — Draft 7")
func runDraft7Suite() throws {
  try runTestSuite(draftDir: "draft7", draft: .draft7)
}

/// Runs all test files in a given draft directory.
private func runTestSuite(draftDir: String, draft: JSONSchema.Draft) throws {
  let suiteRoot = suiteRootURL()
  let dir = suiteRoot.appendingPathComponent(draftDir)
  let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
    .filter { $0.hasSuffix(".json") }
    .sorted()

  var total = 0
  var passed = 0
  var failures: [String] = []

  for file in files {
    let fileURL = dir.appendingPathComponent(file)
    let keyword = file.replacingOccurrences(of: ".json", with: "")
    let data = try Data(contentsOf: fileURL)
    let parsed: JSON
    do {
      parsed = try JSON.parse(data)
    } catch {
      failures.append("[\(keyword)] parse error: \(error)")
      continue
    }
    let testGroups = parsed.arrayValue ?? []

    for group in testGroups {
      guard let groupObj = group.objectValue else { continue }
      let schemaJSON = groupObj["schema"]!
      let tests = groupObj["tests"]?.arrayValue ?? []

      let schema: JSONSchema
      do {
        schema = try JSONSchema(schema: schemaJSON, draft: draft)
      } catch {
        continue
      }

      for testCase in tests {
        guard let testObj = testCase.objectValue else { continue }
        let description = testObj["description"]?.stringValue ?? "unnamed"
        let testData = testObj["data"]!
        let expectedValid = testObj["valid"]?.boolValue ?? false

        total += 1
        let result = schema.validation(of: testData)
        let actualValid = result.valid

        if actualValid == expectedValid {
          passed += 1
        } else {
          let firstError = result.errors.first?.message ?? "no error"
          failures.append(
            "[\(keyword)] \(description): expected \(expectedValid), got \(actualValid) — \(firstError)")
        }
      }
    }
  }

  let pct = String(
    format: "%.1f", Double(passed) / Double(total) * 100)
  let msg = "\(draftDir): \(passed)/\(total) passed (\(pct)%)"

  if failures.isEmpty {
    #expect(passed == total, Comment(rawValue: msg))
  } else {
    let top = failures.prefix(147).joined(separator: "\n  ")
    let remaining = failures.count - min(failures.count, 20)
    let suffix = remaining > 0 ? "\n  ... and \(remaining) more" : ""
    #expect(
      passed == total,
      Comment(rawValue: "\(msg)\n  \(failures.count) failures:\n  \(top)\(suffix)"))
  }
}

/// Returns the URL to the JSON Schema Test Suite submodule.
private func suiteRootURL() -> URL {
  let testsDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()  // Schema/
    .deletingLastPathComponent()  // OrderedJSONTests/
    .deletingLastPathComponent()  // Tests/
  return testsDir.appendingPathComponent("JSON-Schema-Test-Suite/tests")
}
