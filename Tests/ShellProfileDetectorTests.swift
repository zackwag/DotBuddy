import Foundation
import XCTest

@testable import DotBuddyCore

// MARK: - containsSourceLine

final class ContainsSourceLineTests: XCTestCase {
    func testDetectsSourceWithUnquotedPath() {
        let contents = "source /Users/me/.aliases.zsh\n"
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: contents))
    }

    func testDetectsSourceWithDoubleQuotedPath() {
        let contents = "source \"/Users/me/.aliases.zsh\"\n"
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: contents))
    }

    func testDetectsSourceWithSingleQuotedPath() {
        let contents = "source '/Users/me/.aliases.zsh'\n"
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: contents))
    }

    func testDetectsDotSyntaxUnquoted() {
        let contents = ". /Users/me/.aliases.zsh\n"
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: contents))
    }

    func testDetectsDotSyntaxDoubleQuoted() {
        let contents = ". \"/Users/me/.aliases.zsh\"\n"
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: contents))
    }

    func testDetectsDotSyntaxSingleQuoted() {
        let contents = ". '/Users/me/.aliases.zsh'\n"
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: contents))
    }

    func testReturnsFalseWhenNotSourced() {
        let contents = "export PATH=/usr/bin\nalias ll='ls -l'\n"
        XCTAssertFalse(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: contents))
    }

    func testReturnsFalseForDifferentFile() {
        let contents = "source /Users/me/.env.zsh\n"
        XCTAssertFalse(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: contents))
    }

    func testIgnoresCommentedOutSourceLine() {
        let contents = "# source /Users/me/.aliases.zsh\n"
        XCTAssertFalse(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: contents))
    }

    func testHandlesEmptyContents() {
        XCTAssertFalse(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: ""))
    }

    func testDetectsSourceAmongMultipleLines() {
        let contents = """
        export PATH=/usr/bin
        alias ll='ls -l'
        source /Users/me/.aliases.zsh
        echo "done"
        """
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: contents))
    }

    func testDetectsTildeExpansion() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let contents = "source ~/.aliases.zsh\n"
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "\(home)/.aliases.zsh", in: contents))
    }

    func testDetectsTildeExpansionDoubleQuoted() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let contents = "source \"~/.aliases.zsh\"\n"
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "\(home)/.aliases.zsh", in: contents))
    }

    func testHandlesLeadingWhitespace() {
        let contents = "  source /Users/me/.aliases.zsh\n"
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: contents))
    }

    func testDetectsSourceWrapperFunction() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let contents = """
        source_if_found() {
            if [[ -f "$1" ]]; then
                source "$1"
            fi
        }
        source_if_found "$HOME/.aliases.zsh"
        """
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "\(home)/.aliases.zsh", in: contents))
    }

    func testDetectsSourceWrapperWithTildePath() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let contents = """
        safe_source() {
            [[ -f "$1" ]] && source "$1"
        }
        safe_source "~/.aliases.zsh"
        """
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "\(home)/.aliases.zsh", in: contents))
    }

    func testIgnoresNonSourcingFunction() {
        let contents = """
        check_file() {
            echo "$1"
        }
        check_file "/Users/me/.aliases.zsh"
        """
        XCTAssertFalse(ShellProfileDetector.containsSourceLine(for: "/Users/me/.aliases.zsh", in: contents))
    }

    func testDetectsDollarHomeExpansion() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let contents = "source \"$HOME/.aliases.zsh\"\n"
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "\(home)/.aliases.zsh", in: contents))
    }

    func testDetectsBracedHomeExpansion() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let contents = "source \"${HOME}/.aliases.zsh\"\n"
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: "\(home)/.aliases.zsh", in: contents))
    }
}

// MARK: - File I/O

final class ShellProfileDetectorFileTests: XCTestCase {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testIsSourcedInProfileFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let profilePath = dir.appendingPathComponent(".zshrc").path
        let filePath = "/Users/me/.aliases.zsh"
        try "source \"\(filePath)\"\n".write(toFile: profilePath, atomically: true, encoding: .utf8)

        XCTAssertTrue(ShellProfileDetector.isSourced(filePath: filePath, inProfile: profilePath))
    }

    func testIsNotSourcedInProfileFile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let profilePath = dir.appendingPathComponent(".zshrc").path
        try "export PATH=/usr/bin\n".write(toFile: profilePath, atomically: true, encoding: .utf8)

        XCTAssertFalse(ShellProfileDetector.isSourced(filePath: "/Users/me/.aliases.zsh", inProfile: profilePath))
    }

    func testAddSourceLineToExistingProfile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let profilePath = dir.appendingPathComponent(".zshrc").path
        try "export PATH=/usr/bin\n".write(toFile: profilePath, atomically: true, encoding: .utf8)

        let filePath = "/Users/me/.aliases.zsh"
        try ShellProfileDetector.addSourceLine(filePath: filePath, toProfile: profilePath)

        let contents = try String(contentsOfFile: profilePath, encoding: .utf8)
        XCTAssertTrue(contents.contains("source \"/Users/me/.aliases.zsh\""))
        XCTAssertTrue(ShellProfileDetector.containsSourceLine(for: filePath, in: contents))
    }

    func testAddSourceLineCreatesNewProfile() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let profilePath = dir.appendingPathComponent(".zshrc").path
        let filePath = "/Users/me/.aliases.zsh"
        try ShellProfileDetector.addSourceLine(filePath: filePath, toProfile: profilePath)

        let contents = try String(contentsOfFile: profilePath, encoding: .utf8)
        XCTAssertEqual(contents, "source \"/Users/me/.aliases.zsh\"\n")
    }

    func testAddSourceLineAppendsNewline() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let profilePath = dir.appendingPathComponent(".zshrc").path
        try "export FOO=bar".write(toFile: profilePath, atomically: true, encoding: .utf8)

        try ShellProfileDetector.addSourceLine(filePath: "/Users/me/.aliases.zsh", toProfile: profilePath)

        let contents = try String(contentsOfFile: profilePath, encoding: .utf8)
        XCTAssertTrue(contents.hasPrefix("export FOO=bar\n"))
        XCTAssertTrue(contents.contains("source \"/Users/me/.aliases.zsh\""))
    }
}
