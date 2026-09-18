import Foundation

struct CommandSuggestion: Identifiable {
    let id = UUID()
    let command: String
    let count: Int
    let suggestedAlias: String
}

@MainActor
final class HistoryInsights: ObservableObject {
    @Published var suggestions: [CommandSuggestion] = []
    @Published var isLoading = false
    private var didLoad = false

    func analyze(existingAliases: [String: String]) {
        guard !didLoad else { return }
        didLoad = true
        isLoading = true

        Task.detached { [weak self] in
            let suggestions = HistoryInsights.parseHistory(existingAliases: existingAliases)
            await MainActor.run { [weak self] in
                self?.suggestions = suggestions
                self?.isLoading = false
            }
        }
    }

    private nonisolated static func parseHistory(existingAliases: [String: String]) -> [CommandSuggestion] {
        let historyPaths = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zsh_history").path,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".bash_history").path
        ]

        let allLines = readHistoryLines(paths: historyPaths)
        guard !allLines.isEmpty else { return [] }

        let counts = countCommands(in: allLines, existingAliases: existingAliases)
        return buildSuggestions(from: counts, existingAliases: existingAliases)
    }

    private nonisolated static func readHistoryLines(paths: [String]) -> [String] {
        for path in paths {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                return content.components(separatedBy: .newlines)
            } else if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                      let content = String(data: data, encoding: .ascii) {
                return content.components(separatedBy: .newlines)
            }
        }
        return []
    }

    private nonisolated static func countCommands(in lines: [String], existingAliases: [String: String]) -> [String: Int] {
        let aliasedCommands = Set(existingAliases.values)

        var counts: [String: Int] = [:]
        for line in lines {
            guard let normalized = normalizedCommand(from: line), !aliasedCommands.contains(normalized) else { continue }
            counts[normalized, default: 0] += 1
        }
        return counts
    }

    private nonisolated static func normalizedCommand(from line: String) -> String? {
        var cmd = line
        if cmd.hasPrefix(":") {
            guard let semicolonIndex = cmd.firstIndex(of: ";") else { return nil }
            cmd = String(cmd[cmd.index(after: semicolonIndex)...])
        }
        cmd = cmd.trimmingCharacters(in: .whitespaces)
        guard !cmd.isEmpty, cmd.count > 3, !cmd.contains("&&"), !cmd.contains("|") else { return nil }

        let parts = cmd.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard parts.count >= 2, parts.count <= 5 else { return nil }

        return parts.joined(separator: " ")
    }

    private nonisolated static func buildSuggestions(
        from counts: [String: Int],
        existingAliases: [String: String]
    ) -> [CommandSuggestion] {
        let existingNames = Set(existingAliases.keys)
        let filtered = counts
            .filter { $0.value >= 5 }
            .sorted { $0.value > $1.value }
            .prefix(20)

        var usedNames: Set<String> = []
        var result: [CommandSuggestion] = []
        for (cmd, count) in filtered {
            guard result.count < 8 else { break }
            let shortName = generateAliasName(for: cmd)
            if existingNames.contains(shortName) || usedNames.contains(shortName) { continue }
            usedNames.insert(shortName)
            result.append(CommandSuggestion(command: cmd, count: count, suggestedAlias: shortName))
        }
        return result
    }

    private nonisolated static func generateAliasName(for command: String) -> String {
        let parts = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !parts.isEmpty else { return "cmd" }

        if parts.count == 1 { return String(parts[0].prefix(3)) }

        var name = ""
        for part in parts {
            let clean = part.replacingOccurrences(of: "-", with: "")
            name += String(clean.prefix(part == parts[0] ? 1 : 2))
        }
        return String(name.prefix(6)).lowercased()
    }
}
