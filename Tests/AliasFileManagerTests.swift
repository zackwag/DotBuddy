import Foundation
import XCTest

@testable import DotBuddyCore

// MARK: - parseAliases

final class ParseAliasesTests: XCTestCase {
    func testParsesBasicAlias() {
        let aliases = AliasFileManager.parseAliases(from: "alias ll='ls -l'\n")
        XCTAssertEqual(aliases.count, 1)
        XCTAssertEqual(aliases[0].name, "ll")
        XCTAssertEqual(aliases[0].command, "ls -l")
        XCTAssertTrue(aliases[0].isEnabled)
        XCTAssertEqual(aliases[0].group, "")
    }

    func testParsesDoubleQuotedAlias() {
        let aliases = AliasFileManager.parseAliases(from: "alias ll=\"ls -l\"\n")
        XCTAssertEqual(aliases.count, 1)
        XCTAssertEqual(aliases[0].command, "ls -l")
    }

    func testParsesEscapedSingleQuotes() {
        let aliases = AliasFileManager.parseAliases(from: "alias greet='echo '\\''hello'\\'''\n")
        XCTAssertEqual(aliases.count, 1)
        XCTAssertEqual(aliases[0].command, "echo 'hello'")
    }

    func testParsesEscapedDoubleQuotes() {
        let aliases = AliasFileManager.parseAliases(from: "alias greet=\"echo \\\"hello\\\"\"\n")
        XCTAssertEqual(aliases.count, 1)
        XCTAssertEqual(aliases[0].command, "echo \"hello\"")
    }

    func testParsesDisabledAlias() {
        let aliases = AliasFileManager.parseAliases(from: "## alias ll='ls -l'\n")
        XCTAssertEqual(aliases.count, 1)
        XCTAssertEqual(aliases[0].name, "ll")
        XCTAssertFalse(aliases[0].isEnabled)
    }

    func testParsesGroupComment() {
        let input = """
        # Git Aliases
        alias ga='git add'
        alias gc='git commit'
        """
        let aliases = AliasFileManager.parseAliases(from: input)
        XCTAssertEqual(aliases.count, 2)
        XCTAssertEqual(aliases[0].group, "Git Aliases")
        XCTAssertEqual(aliases[1].group, "Git Aliases")
    }

    func testParsesMultipleGroups() {
        let input = """
        # Git
        alias ga='git add'

        # Docker
        alias dps='docker ps'
        """
        let aliases = AliasFileManager.parseAliases(from: input)
        XCTAssertEqual(aliases.count, 2)
        XCTAssertEqual(aliases[0].group, "Git")
        XCTAssertEqual(aliases[1].group, "Docker")
    }

    func testIgnoresEmptyLines() {
        let aliases = AliasFileManager.parseAliases(from: "\n\nalias ll='ls -l'\n\n")
        XCTAssertEqual(aliases.count, 1)
    }

    func testIgnoresNonAliasLines() {
        let input = """
        export PATH="/usr/local/bin:$PATH"
        alias ll='ls -l'
        echo "hello"
        """
        let aliases = AliasFileManager.parseAliases(from: input)
        XCTAssertEqual(aliases.count, 1)
        XCTAssertEqual(aliases[0].name, "ll")
    }

    func testIgnoresShebang() {
        let input = """
        #!/bin/zsh
        alias ll='ls -l'
        """
        let aliases = AliasFileManager.parseAliases(from: input)
        XCTAssertEqual(aliases.count, 1)
    }

    func testHandlesEmptyInput() {
        XCTAssertTrue(AliasFileManager.parseAliases(from: "").isEmpty)
    }

    func testHandlesAliasWithNoCommand() {
        XCTAssertTrue(AliasFileManager.parseAliases(from: "alias empty=''\n").isEmpty)
    }

    func testHandlesAliasWithEqualsInCommand() {
        let aliases = AliasFileManager.parseAliases(from: "alias setenv='export FOO=bar'\n")
        XCTAssertEqual(aliases.count, 1)
        XCTAssertEqual(aliases[0].command, "export FOO=bar")
    }

    func testCommentWithNoFollowingContentIsNotGroup() {
        XCTAssertTrue(AliasFileManager.parseAliases(from: "# Just a comment\n").isEmpty)
    }
}

// MARK: - format

final class AliasFormatTests: XCTestCase {
    func testFormatsEnabledAlias() {
        let alias = Alias(name: "ll", command: "ls -l")
        XCTAssertEqual(AliasFileManager.format(alias: alias), "alias ll='ls -l'")
    }

    func testFormatsDisabledAlias() {
        let alias = Alias(name: "ll", command: "ls -l", isEnabled: false)
        XCTAssertEqual(AliasFileManager.format(alias: alias), "## alias ll='ls -l'")
    }

    func testEscapesSingleQuotesInCommand() {
        let alias = Alias(name: "greet", command: "echo 'hello'")
        XCTAssertEqual(AliasFileManager.format(alias: alias), "alias greet='echo '\\''hello'\\'''")
    }
}

// MARK: - serialize

final class AliasSerializeTests: XCTestCase {
    func testSerializesWithGroups() {
        let aliases = [
            Alias(name: "ga", command: "git add", group: "Git"),
            Alias(name: "gc", command: "git commit", group: "Git"),
            Alias(name: "dps", command: "docker ps", group: "Docker"),
        ]
        let result = AliasFileManager.serialize(aliases: aliases)
        XCTAssertTrue(result.contains("# Git"))
        XCTAssertTrue(result.contains("alias ga='git add'"))
        XCTAssertTrue(result.contains("# Docker"))
    }

    func testSerializesWithoutGroups() {
        let result = AliasFileManager.serialize(aliases: [Alias(name: "ll", command: "ls -l")])
        XCTAssertEqual(result, "alias ll='ls -l'\n")
    }

    func testSerializesEmptyArray() {
        XCTAssertEqual(AliasFileManager.serialize(aliases: []), "\n")
    }

    func testRoundTrips() {
        let original = [
            Alias(name: "ga", command: "git add", group: "Git"),
            Alias(name: "gc", command: "git commit -m 'wip'", group: "Git"),
            Alias(name: "dps", command: "docker ps", group: "Docker"),
            Alias(name: "disabled", command: "echo off", group: "Docker", isEnabled: false),
        ]
        let parsed = AliasFileManager.parseAliases(from: AliasFileManager.serialize(aliases: original))
        XCTAssertEqual(parsed.count, original.count)
        for (a, b) in zip(original, parsed) {
            XCTAssertEqual(a.name, b.name)
            XCTAssertEqual(a.command, b.command)
            XCTAssertEqual(a.group, b.group)
            XCTAssertEqual(a.isEnabled, b.isEnabled)
        }
    }
}

// MARK: - File I/O

final class AliasFileIOTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testLoadsFromFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("aliases.zsh").path
        try "alias ll='ls -l'\n".write(toFile: path, atomically: true, encoding: .utf8)

        let aliases = try AliasFileManager(path: path).load()
        XCTAssertEqual(aliases.count, 1)
        XCTAssertEqual(aliases[0].name, "ll")
    }

    func testSavesAndReloads() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("aliases.zsh").path
        let manager = AliasFileManager(path: path)

        try manager.save([Alias(name: "ga", command: "git add", group: "Git")])
        let reloaded = try manager.load()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded[0].name, "ga")
        XCTAssertEqual(reloaded[0].group, "Git")
    }

    func testCreatesBackup() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("aliases.zsh").path
        try "alias old='echo old'\n".write(toFile: path, atomically: true, encoding: .utf8)

        try AliasFileManager(path: path).save([Alias(name: "new", command: "echo new")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: path + ".bak"))
        XCTAssertTrue(try String(contentsOfFile: path + ".bak", encoding: .utf8).contains("old"))
    }

    func testLoadCreatesFileIfMissing() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("new.zsh").path

        let aliases = try AliasFileManager(path: path).load()
        XCTAssertTrue(aliases.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }
}

// MARK: - SortOrder

final class SortOrderTests: XCTestCase {
    func testToggleCycles() {
        var order = SortOrder.none
        order.toggle()
        XCTAssertEqual(order, .ascending)
        order.toggle()
        XCTAssertEqual(order, .descending)
        order.toggle()
        XCTAssertEqual(order, .none)
    }

    func testSystemImages() {
        XCTAssertEqual(SortOrder.none.systemImage, "arrow.up.arrow.down")
        XCTAssertEqual(SortOrder.ascending.systemImage, "arrow.up")
        XCTAssertEqual(SortOrder.descending.systemImage, "arrow.down")
    }
}
