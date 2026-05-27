import Foundation
import OrderedCollections
import Testing

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

  // Pre-load remote schemas from the remotes/ directory
  let remotesDir = suiteRootURL().deletingLastPathComponent()
    .appendingPathComponent("remotes")
  var remoteSchemas = loadRemoteSchemas(from: remotesDir)

  // Also load well-known metaschemas (e.g., https://json-schema.org/draft/2020-12/schema)
  let metaschemaURLs = loadMetaschemas(from: suiteRootURL())
  for (url, schema) in metaschemaURLs {
    remoteSchemas[url] = schema
  }

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
        schema = try JSONSchema(
          schema: schemaJSON, draft: draft,
          remoteSchemas: remoteSchemas)
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
            "[\(keyword)] \(description): expected \(expectedValid), got \(actualValid) — \(firstError)"
          )
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

/// Loads all JSON files from a directory tree and maps them to remote URLs
/// using the `http://localhost:1234/` base, matching the test suite convention.
/// - Parameter remotesDir: The `remotes/` directory path.
/// - Returns: Dictionary mapping full URLs to parsed JSON schemas.
private func loadRemoteSchemas(from remotesDir: URL) -> [String: JSON] {
  let baseURL = "http://localhost:1234/"
  var result: [String: JSON] = [:]

  guard
    let enumerator = FileManager.default.enumerator(
      at: remotesDir, includingPropertiesForKeys: [])
  else { return result }

  for case let fileURL as URL in enumerator {
    guard fileURL.pathExtension == "json" else { continue }
    guard let data = try? Data(contentsOf: fileURL) else { continue }
    guard let parsed = try? JSON.parse(data) else { continue }

    // Compute relative path from remotesDir to fileURL
    let filePath = fileURL.path
    let remotesPath = remotesDir.path
    let relPath =
      filePath
      .replacingOccurrences(of: remotesPath, with: "")
      .replacingOccurrences(of: "//", with: "/")
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

    // Map to http://localhost:1234/<relative-path>
    let url = baseURL + relPath
    result[url] = parsed
  }

  return result
}

/// Loads well-known metaschemas from a local JSON file that maps
/// metaschema URLs to their content. These are downloaded from the
/// official JSON Schema repository and cached locally.
/// - Parameter suiteRoot: The URL to the test suite root (e.g., .../JSON-Schema-Test-Suite/tests).
/// - Returns: Dictionary mapping metaschema URLs to parsed JSON schemas.
private func loadMetaschemas(from suiteRoot: URL) -> [String: JSON] {
  // suiteRoot = .../OrderedJSON/JSON-Schema-Test-Suite/tests/
  // Go up to project root: .../OrderedJSON/
  let projectRoot =
    suiteRoot
    .deletingLastPathComponent()  // JSON-Schema-Test-Suite/
    .deletingLastPathComponent()  // OrderedJSON/ (project root)
  let metaschemaFile =
    projectRoot
    .appendingPathComponent("OrderedJSONTests/Schema/JSONSchemaTestSuite/metaschemas.json")
  guard let data = try? Data(contentsOf: metaschemaFile) else { return [:] }
  guard let parsed = try? JSON.parse(data) else { return [:] }
  guard let obj = parsed.objectValue else { return [:] }
  var result: [String: JSON] = [:]
  for (url, schema) in obj {
    result[url] = schema
  }
  return result
}
