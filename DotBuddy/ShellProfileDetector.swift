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

        let wrappers = sourcingFunctionNames(in: contents)
        guard !wrappers.isEmpty else { return false }
        let candidates = pathCandidates(for: filePath)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") { continue }
            if matchesFunctionCall(trimmed, functionNames: wrappers, pathCandidates: candidates) {
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

    private static func pathCandidates(for filePath: String) -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let tilde = filePath.replacingOccurrences(of: home, with: "~")
        let dollarHome = filePath.replacingOccurrences(of: home, with: "$HOME")
        var results = [filePath, tilde, dollarHome]
        let envHome = "${HOME}" + dollarHome.dropFirst("$HOME".count)
        if envHome != dollarHome { results.append(envHome) }
        return results
    }

    private static func matchesSourceLine(_ line: String, filePath: String) -> Bool {
        let candidates = pathCandidates(for: filePath)

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

    /// Finds names of shell functions that wrap `source` or `.` (e.g. `source_if_found`).
    static func sourcingFunctionNames(in contents: String) -> Set<String> {
        let pattern = #"^\s*(?:function\s+)?(\w+)\s*\(\s*\)"#
        guard let nameRegex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
            return []
        }
        var names: Set<String> = []
        let lines = contents.components(separatedBy: .newlines)
        var i = 0
        while i < lines.count {
            let line = lines[i]
            let range = NSRange(line.startIndex..., in: line)
            if let match = nameRegex.firstMatch(in: line, range: range),
               let nameRange = Range(match.range(at: 1), in: line) {
                let funcName = String(line[nameRange])
                var braceDepth = 0
                var bodyContainsSource = false
                for j in i..<lines.count {
                    let bodyLine = lines[j].trimmingCharacters(in: .whitespaces)
                    if bodyLine.contains("{") { braceDepth += bodyLine.filter({ $0 == "{" }).count }
                    if bodyLine.contains("}") { braceDepth -= bodyLine.filter({ $0 == "}" }).count }
                    if j > i && (bodyLine.contains("source ") || bodyLine.contains(". \"$1\"") ||
                                 bodyLine.contains(". '$1'") || bodyLine.contains(". $1")) {
                        bodyContainsSource = true
                    }
                    if braceDepth <= 0 && j > i { break }
                }
                if bodyContainsSource { names.insert(funcName) }
            }
            i += 1
        }
        return names
    }

    private static func matchesFunctionCall(
        _ line: String, functionNames: Set<String>, pathCandidates: [String]
    ) -> Bool {
        for name in functionNames {
            let prefix = name + " "
            guard line.hasPrefix(prefix) else { continue }
            let argument = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            let unquoted = stripQuotes(argument)
            for candidate in pathCandidates where unquoted == candidate {
                return true
            }
        }
        return false
    }
}
