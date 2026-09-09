import Foundation
import XCTest

@testable import DotBuddyCore

// MARK: - parseVariables

final class ParseVariablesTests: XCTestCase {
    func testParsesBasicExport() {
        let vars = EnvFileManager.parseVariables(from: "export FOO=\"bar\"\n")
        XCTAssertEqual(vars.count, 1)
        XCTAssertEqual(vars[0].name, "FOO")
        XCTAssertEqual(vars[0].value, "bar")
        XCTAssertTrue(vars[0].isEnabled)
        XCTAssertFalse(vars[0].isSecret)
    }

    func testParsesSingleQuotedValue() {
        let vars = EnvFileManager.parseVariables(from: "export FOO='bar'\n")
        XCTAssertEqual(vars[0].value, "bar")
    }

    func testParsesUnquotedValue() {
        let vars = EnvFileManager.parseVariables(from: "export FOO=bar\n")
        XCTAssertEqual(vars[0].value, "bar")
    }

    func testParsesEscapedDoubleQuotes() {
        let vars = EnvFileManager.parseVariables(from: "export MSG=\"say \\\"hello\\\"\"\n")
        XCTAssertEqual(vars[0].value, "say \"hello\"")
    }

    func testParsesSecretMarker() {
        let vars = EnvFileManager.parseVariables(from: "export API_KEY=\"abc123\" # [secret]\n")
        XCTAssertEqual(vars[0].name, "API_KEY")
        XCTAssertEqual(vars[0].value, "abc123")
        XCTAssertTrue(vars[0].isSecret)
    }

    func testParsesDisabledVariable() {
        let vars = EnvFileManager.parseVariables(from: "## export FOO=\"bar\"\n")
        XCTAssertEqual(vars[0].name, "FOO")
        XCTAssertFalse(vars[0].isEnabled)
    }

    func testParsesGroups() {
        let input = """
        # API Keys
        export KEY1="abc"
        export KEY2="def"

        # Paths
        export MY_PATH="/usr/local"
        """
        let vars = EnvFileManager.parseVariables(from: input)
        XCTAssertEqual(vars.count, 3)
        XCTAssertEqual(vars[0].group, "API Keys")
        XCTAssertEqual(vars[1].group, "API Keys")
        XCTAssertEqual(vars[2].group, "Paths")
    }

    func testIgnoresNonExportLines() {
        let input = """
        alias ll='ls -l'
        export FOO="bar"
        echo hello
        """
        let vars = EnvFileManager.parseVariables(from: input)
        XCTAssertEqual(vars.count, 1)
        XCTAssertEqual(vars[0].name, "FOO")
    }

    func testHandlesEmptyInput() {
        XCTAssertTrue(EnvFileManager.parseVariables(from: "").isEmpty)
    }

    func testHandlesEqualsInValue() {
        let vars = EnvFileManager.parseVariables(from: "export CONN=\"host=localhost;port=5432\"\n")
        XCTAssertEqual(vars[0].value, "host=localhost;port=5432")
    }

    func testIgnoresShebang() {
        let input = """
        #!/bin/zsh
        export FOO="bar"
        """
        XCTAssertEqual(EnvFileManager.parseVariables(from: input).count, 1)
    }

    func testDisabledSecretVariable() {
        let vars = EnvFileManager.parseVariables(from: "## export TOKEN=\"secret\" # [secret]\n")
        XCTAssertEqual(vars.count, 1)
        XCTAssertFalse(vars[0].isEnabled)
        XCTAssertTrue(vars[0].isSecret)
        XCTAssertEqual(vars[0].value, "secret")
    }
}

// MARK: - format

final class EnvFormatTests: XCTestCase {
    func testFormatsEnabledVariable() {
        let v = EnvVariable(name: "FOO", value: "bar")
        XCTAssertEqual(EnvFileManager.format(variable: v), "export FOO=\"bar\"")
    }

    func testFormatsDisabledVariable() {
        let v = EnvVariable(name: "FOO", value: "bar", isEnabled: false)
        XCTAssertEqual(EnvFileManager.format(variable: v), "## export FOO=\"bar\"")
    }

    func testFormatsSecretVariable() {
        let v = EnvVariable(name: "KEY", value: "abc", isSecret: true)
        XCTAssertEqual(EnvFileManager.format(variable: v), "export KEY=\"abc\" # [secret]")
    }

    func testEscapesDoubleQuotesInValue() {
        let v = EnvVariable(name: "MSG", value: "say \"hello\"")
        XCTAssertEqual(EnvFileManager.format(variable: v), "export MSG=\"say \\\"hello\\\"\"")
    }

    func testDisabledSecret() {
        let v = EnvVariable(name: "KEY", value: "abc", isSecret: true, isEnabled: false)
        XCTAssertEqual(EnvFileManager.format(variable: v), "## export KEY=\"abc\" # [secret]")
    }
}

// MARK: - serialize

final class EnvSerializeTests: XCTestCase {
    func testSerializesWithGroups() {
        let vars = [
            EnvVariable(name: "KEY", value: "abc", group: "API"),
            EnvVariable(name: "PATH", value: "/usr", group: "System"),
        ]
        let result = EnvFileManager.serialize(variables: vars)
        XCTAssertTrue(result.contains("# API"))
        XCTAssertTrue(result.contains("# System"))
        XCTAssertTrue(result.contains("export KEY=\"abc\""))
    }

    func testSerializesEmpty() {
        XCTAssertEqual(EnvFileManager.serialize(variables: []), "\n")
    }

    func testRoundTrips() {
        let original = [
            EnvVariable(name: "FOO", value: "bar", group: "Test"),
            EnvVariable(name: "SECRET", value: "abc", group: "Test", isSecret: true),
            EnvVariable(name: "OFF", value: "val", group: "Other", isEnabled: false),
        ]
        let parsed = EnvFileManager.parseVariables(from: EnvFileManager.serialize(variables: original))
        XCTAssertEqual(parsed.count, original.count)
        for (a, b) in zip(original, parsed) {
            XCTAssertEqual(a.name, b.name)
            XCTAssertEqual(a.value, b.value)
            XCTAssertEqual(a.group, b.group)
            XCTAssertEqual(a.isSecret, b.isSecret)
            XCTAssertEqual(a.isEnabled, b.isEnabled)
        }
    }
}

// MARK: - File I/O

final class EnvFileIOTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testLoadsFromFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("env.zsh").path
        try "export FOO=\"bar\"\n".write(toFile: path, atomically: true, encoding: .utf8)

        let vars = try EnvFileManager(path: path).load()
        XCTAssertEqual(vars.count, 1)
        XCTAssertEqual(vars[0].name, "FOO")
    }

    func testSavesAndReloads() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("env.zsh").path
        let manager = EnvFileManager(path: path)

        try manager.save([EnvVariable(name: "DB", value: "postgres://localhost", group: "Database")])
        let reloaded = try manager.load()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded[0].name, "DB")
        XCTAssertEqual(reloaded[0].group, "Database")
    }

    func testCreatesBackup() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("env.zsh").path
        try "export OLD=\"val\"\n".write(toFile: path, atomically: true, encoding: .utf8)

        try EnvFileManager(path: path).save([EnvVariable(name: "NEW", value: "val")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: path + ".bak"))
    }
}
