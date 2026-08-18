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
        let content = Self.serialize(aliases: aliases)
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func format(alias: Alias) -> String {
        "alias \(alias.name)='\(alias.command.replacingOccurrences(of: "'", with: "'\\''"))'"
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

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("#") {
                currentGroup = String(trimmed.dropFirst())
                    .trimmingCharacters(in: .whitespaces)
                continue
            }

            if let alias = parseLine(trimmed, group: currentGroup) {
                aliases.append(alias)
            }
        }

        return aliases
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
