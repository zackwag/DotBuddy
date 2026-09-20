import Foundation
import XCTest

@testable import DotBuddyCore

final class CommandConflictCheckerTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a temporary directory with the given executable names as
    /// empty files with the executable permission bit set.
    private func makeTempBin(executables: [String]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for name in executables {
            let path = dir.appendingPathComponent(name).path
            FileManager.default.createFile(atPath: path, contents: nil)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: path
            )
        }
        return dir
    }

    // MARK: - Tests

    func testFindsConflictInSearchPath() throws {
        let dir = try makeTempBin(executables: ["grep"])
        defer { try? FileManager.default.removeItem(at: dir) }

        let checker = CommandConflictChecker(searchPaths: [dir.path])
        let result = checker.conflictingPath(for: "grep")
        XCTAssertEqual(result, dir.appendingPathComponent("grep").path)
    }

    func testReturnsNilWhenNoConflict() throws {
        let dir = try makeTempBin(executables: [])
        defer { try? FileManager.default.removeItem(at: dir) }

        let checker = CommandConflictChecker(searchPaths: [dir.path])
        XCTAssertNil(checker.conflictingPath(for: "nonexistent_command_xyz"))
    }

    func testReturnsNilForEmptyName() {
        let checker = CommandConflictChecker(searchPaths: [])
        XCTAssertNil(checker.conflictingPath(for: ""))
    }

    func testReturnsNilForWhitespaceName() {
        let checker = CommandConflictChecker(searchPaths: [])
        XCTAssertNil(checker.conflictingPath(for: "   "))
    }

    func testTrimsWhitespace() throws {
        let dir = try makeTempBin(executables: ["ls"])
        defer { try? FileManager.default.removeItem(at: dir) }

        let checker = CommandConflictChecker(searchPaths: [dir.path])
        XCTAssertNotNil(checker.conflictingPath(for: "  ls  "))
    }

    func testReturnsFirstMatchingPath() throws {
        let dir1 = try makeTempBin(executables: ["cat"])
        let dir2 = try makeTempBin(executables: ["cat"])
        defer {
            try? FileManager.default.removeItem(at: dir1)
            try? FileManager.default.removeItem(at: dir2)
        }

        let checker = CommandConflictChecker(searchPaths: [dir1.path, dir2.path])
        let result = checker.conflictingPath(for: "cat")
        XCTAssertEqual(result, dir1.appendingPathComponent("cat").path)
    }

    func testCachesResults() throws {
        let dir = try makeTempBin(executables: ["git"])
        defer { try? FileManager.default.removeItem(at: dir) }

        let checker = CommandConflictChecker(searchPaths: [dir.path])

        let first = checker.conflictingPath(for: "git")
        XCTAssertNotNil(first)

        // Remove the file to prove the cache is used
        try FileManager.default.removeItem(atPath: dir.appendingPathComponent("git").path)

        let second = checker.conflictingPath(for: "git")
        XCTAssertEqual(first, second)
    }

    func testClearCacheInvalidatesResults() throws {
        let dir = try makeTempBin(executables: ["node"])
        defer { try? FileManager.default.removeItem(at: dir) }

        let checker = CommandConflictChecker(searchPaths: [dir.path])

        let first = checker.conflictingPath(for: "node")
        XCTAssertNotNil(first)

        // Remove the file and clear cache
        try FileManager.default.removeItem(atPath: dir.appendingPathComponent("node").path)
        checker.clearCache()

        let second = checker.conflictingPath(for: "node")
        XCTAssertNil(second)
    }

    func testCachesNilResults() throws {
        let dir = try makeTempBin(executables: [])
        defer { try? FileManager.default.removeItem(at: dir) }

        let checker = CommandConflictChecker(searchPaths: [dir.path])

        XCTAssertNil(checker.conflictingPath(for: "phantom"))

        // Even after creating the file, nil should still be cached
        let path = dir.appendingPathComponent("phantom").path
        FileManager.default.createFile(atPath: path, contents: nil)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)

        XCTAssertNil(checker.conflictingPath(for: "phantom"))
    }

    func testIgnoresNonExecutableFiles() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let path = dir.appendingPathComponent("readme").path
        FileManager.default.createFile(atPath: path, contents: nil)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: path)

        let checker = CommandConflictChecker(searchPaths: [dir.path])
        XCTAssertNil(checker.conflictingPath(for: "readme"))
    }

    func testDefaultSearchPathsArePopulated() {
        XCTAssertFalse(CommandConflictChecker.defaultSearchPaths.isEmpty)
        XCTAssertTrue(CommandConflictChecker.defaultSearchPaths.contains("/usr/bin"))
        XCTAssertTrue(CommandConflictChecker.defaultSearchPaths.contains("/bin"))
    }

    func testSharedInstanceExists() {
        let shared = CommandConflictChecker.shared
        XCTAssertNotNil(shared)
    }

    func testMultipleSearchPaths() throws {
        let dir1 = try makeTempBin(executables: ["tool1"])
        let dir2 = try makeTempBin(executables: ["tool2"])
        defer {
            try? FileManager.default.removeItem(at: dir1)
            try? FileManager.default.removeItem(at: dir2)
        }

        let checker = CommandConflictChecker(searchPaths: [dir1.path, dir2.path])
        XCTAssertNotNil(checker.conflictingPath(for: "tool1"))
        XCTAssertNotNil(checker.conflictingPath(for: "tool2"))
        XCTAssertNil(checker.conflictingPath(for: "tool3"))
    }

    func testEmptySearchPaths() {
        let checker = CommandConflictChecker(searchPaths: [])
        XCTAssertNil(checker.conflictingPath(for: "ls"))
    }
}
