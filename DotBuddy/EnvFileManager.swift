import Foundation

struct EnvFileManager {
    let path: String

    func load() throws -> [EnvVariable] {
        guard FileManager.default.fileExists(atPath: path) else {
            FileManager.default.createFile(atPath: path, contents: nil)
            return []
        }
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        return Self.parseVariables(from: contents)
    }

    func save(_ variables: [EnvVariable]) throws {
        if FileManager.default.fileExists(atPath: path) {
            let backupPath = path + ".bak"
            try? FileManager.default.removeItem(atPath: backupPath)
            try? FileManager.default.copyItem(atPath: path, toPath: backupPath)
        }
        let content = Self.serialize(variables: variables)
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func format(variable: EnvVariable) -> String {
        var line = "export \(variable.name)=\"\(variable.value.replacingOccurrences(of: "\"", with: "\\\""))\""
        if variable.isSecret {
            line += " # [secret]"
        }
        return variable.isEnabled ? line : "## \(line)"
    }

    static func serialize(variables: [EnvVariable]) -> String {
        var lines: [String] = []
        var currentGroup = ""

        for variable in variables {
            if variable.group != currentGroup {
                if !lines.isEmpty {
                    lines.append("")
                }
                if !variable.group.isEmpty {
                    lines.append("# \(variable.group)")
                }
                currentGroup = variable.group
            }
            lines.append(format(variable: variable))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    static func parseVariables(from contents: String) -> [EnvVariable] {
        var variables: [EnvVariable] = []
        var currentGroup = ""
        let lines = contents.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("##") {
                let uncommented = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if let variable = parseLine(uncommented, group: currentGroup) {
                    var disabled = variable
                    disabled.isEnabled = false
                    variables.append(disabled)
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

            if let variable = parseLine(trimmed, group: currentGroup) {
                variables.append(variable)
            }
        }

        return variables
    }

    private static func hasContentAfter(index: Int, in lines: [String]) -> Bool {
        for i in (index + 1)..<lines.count {
            let next = lines[i].trimmingCharacters(in: .whitespaces)
            if next.isEmpty { continue }
            return next.hasPrefix("export ") || next.hasPrefix("##")
        }
        return false
    }

    static func loadVariables(from url: URL) throws -> [EnvVariable] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return parseVariables(from: contents)
    }

    private static func parseLine(_ line: String, group: String) -> EnvVariable? {
        let isSecret = line.hasSuffix("# [secret]")
        var working = line

        if isSecret, let commentRange = working.range(of: " # [secret]", options: .backwards) {
            working = String(working[working.startIndex..<commentRange.lowerBound])
        }

        if working.hasPrefix("export ") {
            working = String(working.dropFirst(7))
        } else {
            return nil
        }

        guard let equalsIndex = working.firstIndex(of: "=") else { return nil }

        let name = String(working[working.startIndex..<equalsIndex])
            .trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        var value = String(working[working.index(after: equalsIndex)...])
            .trimmingCharacters(in: .whitespaces)

        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
           (value.hasPrefix("'") && value.hasSuffix("'")) {
            value = String(value.dropFirst().dropLast())
        }

        value = value.replacingOccurrences(of: "\\\"", with: "\"")

        return EnvVariable(name: name, value: value, group: group, isSecret: isSecret)
    }
}
