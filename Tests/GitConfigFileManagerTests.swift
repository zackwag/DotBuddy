import Foundation
import XCTest

@testable import DotBuddyCore

final class ParseGitConfigTests: XCTestCase {
    func testParsesSectionsAndKeys() {
        let input = """
        [user]
        \tname = Jane Doe
        \temail = jane@example.com
        [init]
        \tdefaultBranch = main
        """
        let entries = GitConfigFileManager.parseEntries(from: input)
        XCTAssertEqual(entries.map(\.section), ["user", "user", "init"])
        XCTAssertEqual(entries.map(\.key), ["name", "email", "defaultBranch"])
        XCTAssertEqual(entries.map(\.value), ["Jane Doe", "jane@example.com", "main"])
    }

    func testParsesSubsections() {
        let input = "[credential \"https://dev.azure.com\"]\n\tuseHttpPath = true\n[includeIf \"gitdir:~/work/\"]\n\tpath = ~/.gitconfig-work\n"
        let entries = GitConfigFileManager.parseEntries(from: input)
        XCTAssertEqual(entries.map(\.section), ["credential \"https://dev.azure.com\"", "includeIf \"gitdir:~/work/\""])
    }

    func testKeepsMultiValuedKeysAndEmptyReset() {
        let input = "[credential]\n\thelper = \n\thelper = /usr/local/bin/gcm\n"
        let entries = GitConfigFileManager.parseEntries(from: input)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].value, "")
        XCTAssertEqual(entries[1].value, "/usr/local/bin/gcm")
    }

    func testBareKeyIsTrue() {
        let entries = GitConfigFileManager.parseEntries(from: "[core]\n\tbare ; comment\n")
        XCTAssertEqual(entries.first?.key, "bare")
        XCTAssertEqual(entries.first?.value, "true")
    }

    func testStripsCommentsOutsideQuotes() {
        let input = """
        # top comment
        ; another
        [alias] # header comment
        \tlg = log --oneline # trailing
        \tx = "echo #notcomment; ok"
        """
        let entries = GitConfigFileManager.parseEntries(from: input)
        XCTAssertEqual(entries.map(\.value), ["log --oneline", "echo #notcomment; ok"])
    }

    func testHandlesEscapesAndQuotedWhitespace() {
        let input = #"[a]"# + "\n" + #"  k = "  padded " \"q\" back\\slash\ttab"#
        let entries = GitConfigFileManager.parseEntries(from: input)
        XCTAssertEqual(entries.first?.value, "  padded  \"q\" back\\slash\ttab")
    }

    func testHandlesLineContinuation() {
        let input = "[alias]\n\tst = status \\\n  --short\n\tco = checkout\n"
        let entries = GitConfigFileManager.parseEntries(from: input)
        XCTAssertEqual(entries.map(\.value), ["status   --short", "checkout"])
    }

    func testDropsKeysBeforeAnySection() {
        let entries = GitConfigFileManager.parseEntries(from: "orphan = 1\n[a]\n\tk = v\n")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].key, "k")
    }

    func testEmptyInput() {
        XCTAssertTrue(GitConfigFileManager.parseEntries(from: "").isEmpty)
    }
}

final class SerializeGitConfigTests: XCTestCase {
    func testGroupsConsecutiveEntriesUnderOneHeader() {
        let output = GitConfigFileManager.serialize(entries: [
            GitConfigEntry(section: "user", key: "name", value: "Jane"),
            GitConfigEntry(section: "user", key: "email", value: "j@x.com"),
            GitConfigEntry(section: "credential", key: "helper", value: ""),
        ])
        XCTAssertEqual(output, "[user]\n\tname = Jane\n\temail = j@x.com\n[credential]\n\thelper =\n")
    }

    func testQuotesAndEscapesWhenNeeded() {
        XCTAssertEqual(GitConfigFileManager.escape("plain value"), "plain value")
        XCTAssertEqual(GitConfigFileManager.escape(" lead"), "\" lead\"")
        XCTAssertEqual(GitConfigFileManager.escape("a#b"), "\"a#b\"")
        XCTAssertEqual(GitConfigFileManager.escape("say \"hi\"\\"), "say \\\"hi\\\"\\\\")
        XCTAssertEqual(GitConfigFileManager.escape("a\nb"), "a\\nb")
    }

    func testRoundTrip() {
        let original = [
            GitConfigEntry(section: "remote \"origin\"", key: "url", value: "git@github.com:a/b.git"),
            GitConfigEntry(section: "alias", key: "x", value: "!f() { echo \"$1\" # hi; }; f"),
            GitConfigEntry(section: "alias", key: "pad", value: "  spaced\ttab  "),
            GitConfigEntry(section: "credential", key: "helper", value: ""),
            GitConfigEntry(section: "user", key: "name", value: "Jane"),
            GitConfigEntry(section: "alias", key: "later", value: "log"),
        ]
        let parsed = GitConfigFileManager.parseEntries(from: GitConfigFileManager.serialize(entries: original))
        XCTAssertEqual(parsed.map(\.section), original.map(\.section))
        XCTAssertEqual(parsed.map(\.key), original.map(\.key))
        XCTAssertEqual(parsed.map(\.value), original.map(\.value))
    }

    func testValidation() {
        XCTAssertTrue(GitConfigFileManager.isValidSection("user"))
        XCTAssertTrue(GitConfigFileManager.isValidSection("url \"git@github.com:\""))
        XCTAssertTrue(GitConfigFileManager.isValidSection("branch.main"))
        XCTAssertFalse(GitConfigFileManager.isValidSection(""))
        XCTAssertFalse(GitConfigFileManager.isValidSection("bad name"))
        XCTAssertFalse(GitConfigFileManager.isValidSection("remote \"unterminated"))
        XCTAssertTrue(GitConfigFileManager.isValidKey("defaultBranch"))
        XCTAssertTrue(GitConfigFileManager.isValidKey("use-http-path"))
        XCTAssertFalse(GitConfigFileManager.isValidKey("1abc"))
        XCTAssertFalse(GitConfigFileManager.isValidKey("has space"))
        XCTAssertFalse(GitConfigFileManager.isValidKey("a.b"))
    }
}

final class GitConfigFileManagerIOTests: XCTestCase {
    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory() + "dotbuddy-git-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    func testSaveCreatesBackup() throws {
        let path = tempDir + "/.gitconfig"
        let manager = GitConfigFileManager(path: path)
        try manager.save([GitConfigEntry(section: "user", key: "name", value: "v1")])
        try manager.save([GitConfigEntry(section: "user", key: "name", value: "v2")])
        XCTAssertEqual(try manager.load().first?.value, "v2")
        XCTAssertTrue(try String(contentsOfFile: path + ".bak", encoding: .utf8).contains("v1"))
    }

    func testSaveThroughSymlinkKeepsLink() throws {
        let real = tempDir + "/dotfiles-gitconfig"
        let link = tempDir + "/.gitconfig"
        try "[user]\n\tname = old\n".write(toFile: real, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: real)

        try GitConfigFileManager(path: link).save([GitConfigEntry(section: "user", key: "name", value: "new")])

        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link), real)
        XCTAssertTrue(try String(contentsOfFile: real, encoding: .utf8).contains("new"))
    }

    func testLoadNonexistentReturnsEmpty() throws {
        XCTAssertTrue(try GitConfigFileManager(path: tempDir + "/nope").load().isEmpty)
    }
}
