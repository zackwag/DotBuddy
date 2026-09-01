import Foundation

struct AliasFileManager {
    let path: String

    func load() throws -> [Alias] {
        guard FileManager.default.fileExists(atPath: path) else {
            FileManager.default.createFile(atPath: path, contents: nil)
            return []
        }
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        return Self.parseAliases(from: contents)
    }

    func save(_ aliases: [Alias]) throws {
        if FileManager.default.fileExists(atPath: path) {
            let backupPath = path + ".bak"
            try? FileManager.default.removeItem(atPath: backupPath)
            try? FileManager.default.copyItem(atPath: path, toPath: backupPath)
        }
        let content = Self.serialize(aliases: aliases)
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func format(alias: Alias) -> String {
        let line = "alias \(alias.name)='\(alias.command.replacingOccurrences(of: "'", with: "'\\''"))'"
        return alias.isEnabled ? line : "## \(line)"
    }

    static func serialize(aliases: [Alias]) -> String {
        var lines: [String] = []
        var currentGroup = ""

        for alias in aliases {
            if alias.group != currentGroup {
                if !lines.isEmpty {
                    lines.append("")
                }
                if !alias.group.isEmpty {
                    lines.append("# \(alias.group)")
                }
                currentGroup = alias.group
            }
            lines.append(format(alias: alias))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func parseAliases(from contents: String) -> [Alias] {
        var aliases: [Alias] = []
        var currentGroup = ""
        let lines = contents.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("##") {
                let uncommented = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if let alias = parseLine(uncommented, group: currentGroup) {
                    var disabled = alias
                    disabled.isEnabled = false
                    aliases.append(disabled)
                }
                continue
            }

            if trimmed.hasPrefix("#") && !trimmed.hasPrefix("#!/") {
                let candidate = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty && hasContentAfter(index: index, in: lines) {
                    currentGroup = candidate
                }
                continue
            }

            if let alias = parseLine(trimmed, group: currentGroup) {
                aliases.append(alias)
            }
        }

        return aliases
    }

    private static func hasContentAfter(index: Int, in lines: [String]) -> Bool {
        for i in (index + 1)..<lines.count {
            let next = lines[i].trimmingCharacters(in: .whitespaces)
            if next.isEmpty { continue }
            return next.hasPrefix("alias ") || next.hasPrefix("##")
        }
        return false
    }

    static func loadAliases(from url: URL) throws -> [Alias] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return parseAliases(from: contents)
    }

    private static func parseLine(_ line: String, group: String) -> Alias? {
        guard line.hasPrefix("alias ") else { return nil }

        let afterAlias = String(line.dropFirst(6))
        guard let equalsIndex = afterAlias.firstIndex(of: "=") else { return nil }

        let name = String(afterAlias[afterAlias.startIndex..<equalsIndex])
            .trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        var command = String(afterAlias[afterAlias.index(after: equalsIndex)...])
            .trimmingCharacters(in: .whitespaces)

        let wasDoubleQuoted = command.hasPrefix("\"") && command.hasSuffix("\"")
        if (command.hasPrefix("'") && command.hasSuffix("'")) || wasDoubleQuoted {
            command = String(command.dropFirst().dropLast())
        }

        if wasDoubleQuoted {
            command = command.replacingOccurrences(of: "\\\"", with: "\"")
        } else {
            command = command.replacingOccurrences(of: "'\\''", with: "'")
        }

        guard !command.isEmpty else { return nil }
        return Alias(name: name, command: command, group: group)
    }
}
