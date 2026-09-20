import Foundation

struct ShellProfileDetector {
    static let profilePaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.zshrc",
            "\(home)/.bashrc",
            "\(home)/.bash_profile",
            "\(home)/.zprofile",
            "\(home)/.profile",
        ]
    }()

    /// Checks whether the given file path is sourced in any common shell profile.
    static func isSourced(filePath: String) -> Bool {
        for profile in profilePaths where FileManager.default.fileExists(atPath: profile) {
            if isSourced(filePath: filePath, inProfile: profile) {
                return true
            }
        }
        return false
    }

    /// Checks whether the given file path is sourced in a specific profile file.
    static func isSourced(filePath: String, inProfile profilePath: String) -> Bool {
        guard let contents = try? String(contentsOfFile: profilePath, encoding: .utf8) else {
            return false
        }
        return containsSourceLine(for: filePath, in: contents)
    }

    /// Checks whether the given content contains a source line for the specified file path.
    static func containsSourceLine(for filePath: String, in contents: String) -> Bool {
        let lines = contents.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") { continue }
            if matchesSourceLine(trimmed, filePath: filePath) {
                return true
            }
        }
        return false
    }

    /// Returns the first existing shell profile path, or ~/.zshrc as a default.
    static func firstExistingProfile() -> String {
        for profile in profilePaths where FileManager.default.fileExists(atPath: profile) {
            return profile
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.zshrc"
    }

    /// Appends a source line for the given file path to the specified shell profile.
    static func addSourceLine(filePath: String, toProfile profilePath: String) throws {
        var contents = ""
        if FileManager.default.fileExists(atPath: profilePath) {
            contents = try String(contentsOfFile: profilePath, encoding: .utf8)
        }

        let sourceLine = "source \"\(filePath)\""

        if !contents.isEmpty && !contents.hasSuffix("\n") {
            contents += "\n"
        }
        contents += sourceLine + "\n"

        try contents.write(toFile: profilePath, atomically: true, encoding: .utf8)
    }

    // MARK: - Private

    private static func matchesSourceLine(_ line: String, filePath: String) -> Bool {
        let tildeFilePath = filePath.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
        let candidates = [filePath, tildeFilePath]

        for prefix in ["source ", ". "] {
            guard line.hasPrefix(prefix) else { continue }
            let argument = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            let unquoted = stripQuotes(argument)
            for candidate in candidates where unquoted == candidate {
                return true
            }
        }
        return false
    }

    private static func stripQuotes(_ string: String) -> String {
        var result = string
        if (result.hasPrefix("\"") && result.hasSuffix("\"")) ||
            (result.hasPrefix("'") && result.hasSuffix("'")) {
            result = String(result.dropFirst().dropLast())
        }
        return result
    }
}
