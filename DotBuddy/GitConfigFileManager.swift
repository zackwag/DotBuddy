import Foundation

struct GitConfigFileManager {
    let path: String

    func load() throws -> [GitConfigEntry] {
        guard FileManager.default.fileExists(atPath: path) else {
            return []
        }
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        return Self.parseEntries(from: contents)
    }

    func save(_ entries: [GitConfigEntry]) throws {
        // ~/.gitconfig is often symlinked into a dotfiles repo; an atomic write would replace the link with a plain file.
        let target = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        if FileManager.default.fileExists(atPath: target) {
            let backupPath = target + ".bak"
            try? FileManager.default.removeItem(atPath: backupPath)
            try? FileManager.default.copyItem(atPath: target, toPath: backupPath)
        }
        let content = Self.serialize(entries: entries)
        try content.write(toFile: target, atomically: true, encoding: .utf8)
    }

    // MARK: - Validation

    static func isValidSection(_ section: String) -> Bool {
        section.range(of: #"^[A-Za-z0-9.-]+( "([^"\\\n]|\\.)*")?$"#, options: .regularExpression) != nil
    }

    static func isValidKey(_ key: String) -> Bool {
        key.range(of: #"^[A-Za-z][A-Za-z0-9-]*$"#, options: .regularExpression) != nil
    }

    // MARK: - Set

    /// Sets each key like `git config --global section.key value`: the first existing match is updated and
    /// any duplicates are removed; otherwise the entry goes at the end of its section (or of the file).
    static func setting(_ values: [GitConfigEntry], in entries: [GitConfigEntry]) -> [GitConfigEntry] {
        var result = entries
        for value in values {
            let matches = { (entry: GitConfigEntry) in
                normalizedSection(entry.section) == normalizedSection(value.section) &&
                entry.key.caseInsensitiveCompare(value.key) == .orderedSame
            }
            if let first = result.firstIndex(where: matches) {
                result[first].value = value.value
                let keptID = result[first].id
                result.removeAll { matches($0) && $0.id != keptID }
            } else if let last = result.lastIndex(where: { normalizedSection($0.section) == normalizedSection(value.section) }) {
                result.insert(value, at: last + 1)
            } else {
                result.append(value)
            }
        }
        return result
    }

    /// Section names are case-insensitive in git; quoted subsection names are case-sensitive.
    private static func normalizedSection(_ section: String) -> String {
        let parts = section.split(separator: " ", maxSplits: 1)
        guard let name = parts.first else {
            return section
        }
        return name.lowercased() + (parts.count > 1 ? " " + parts[1] : "")
    }

    // MARK: - Serialize

    static func serialize(entries: [GitConfigEntry]) -> String {
        var lines: [String] = []
        var currentSection: String?

        for entry in entries {
            if entry.section != currentSection {
                lines.append("[\(entry.section)]")
                currentSection = entry.section
            }
            let value = escape(entry.value)
            lines.append(value.isEmpty ? "\t\(entry.key) =" : "\t\(entry.key) = \(value)")
        }

        return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }

    static func escape(_ value: String) -> String {
        var out = ""
        for char in value {
            switch char {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            default: out.append(char)
            }
        }
        let needsQuotes = value.first == " " || value.last == " " || value.contains("#") || value.contains(";")
        return needsQuotes ? "\"\(out)\"" : out
    }

    // MARK: - Parse

    /// Comments and blank lines are not preserved; keys outside any section are invalid in git and are dropped.
    static func parseEntries(from contents: String) -> [GitConfigEntry] {
        var entries: [GitConfigEntry] = []
        var section: String?
        let lines = contents.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")

        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            index += 1

            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
                continue
            }

            if trimmed.hasPrefix("[") {
                section = parseHeader(trimmed)
                continue
            }

            guard let section else {
                continue
            }

            if let equals = trimmed.firstIndex(of: "=") {
                let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
                let value = parseValue(trimmed[trimmed.index(after: equals)...], lines: lines, index: &index)
                entries.append(GitConfigEntry(section: section, key: key, value: value))
            } else {
                // A bare key (no `=`) is shorthand for `true`.
                let key = trimmed.prefix { $0 != "#" && $0 != ";" }.trimmingCharacters(in: .whitespaces)
                entries.append(GitConfigEntry(section: section, key: key, value: "true"))
            }
        }

        return entries
    }

    private static func parseHeader(_ line: String) -> String? {
        var inQuote = false
        var escaped = false
        for (offset, char) in line.enumerated().dropFirst() {
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                inQuote.toggle()
            } else if char == "]" && !inQuote {
                let start = line.index(after: line.startIndex)
                let end = line.index(line.startIndex, offsetBy: offset)
                return line[start..<end].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static let escapes: [Character: Character] = ["n": "\n", "t": "\t", "b": "\u{8}", "\\": "\\", "\"": "\""]

    /// Follows git's rules: unquoted leading/trailing whitespace is dropped, `#`/`;` start a comment outside quotes,
    /// and a trailing backslash continues the value onto the next line.
    private static func parseValue(_ start: Substring, lines: [String], index: inout Int) -> String {
        var chars = Array(start)
        var position = 0
        var result = ""
        var pendingSpace = ""
        var inQuote = false

        while position < chars.count {
            let char = chars[position]
            position += 1

            if char == "\\" {
                if position >= chars.count {
                    guard index < lines.count else {
                        break
                    }
                    chars = Array(lines[index])
                    index += 1
                    position = 0
                    continue
                }
                let next = chars[position]
                position += 1
                result += pendingSpace
                pendingSpace = ""
                result.append(escapes[next] ?? next)
                continue
            }

            if char == "\"" {
                result += pendingSpace
                pendingSpace = ""
                inQuote.toggle()
                continue
            }

            if !inQuote && (char == "#" || char == ";") {
                break
            }

            if !inQuote && char.isWhitespace {
                if !result.isEmpty {
                    pendingSpace.append(char)
                }
                continue
            }

            result += pendingSpace
            pendingSpace = ""
            result.append(char)
        }

        return result
    }
}
