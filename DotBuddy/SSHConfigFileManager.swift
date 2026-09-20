import Foundation

struct SSHConfigFileManager {
    let path: String

    func load() throws -> [SSHHost] {
        guard FileManager.default.fileExists(atPath: path) else {
            return []
        }
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        return Self.parseHosts(from: contents)
    }

    func save(_ hosts: [SSHHost]) throws {
        if FileManager.default.fileExists(atPath: path) {
            let backupPath = path + ".bak"
            try? FileManager.default.removeItem(atPath: backupPath)
            try? FileManager.default.copyItem(atPath: path, toPath: backupPath)
        }
        let content = Self.serialize(hosts: hosts)
        let dir = (path as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: dir) {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func serialize(hosts: [SSHHost]) -> String {
        var lines: [String] = []
        var currentGroup = ""

        for host in hosts {
            if host.group != currentGroup {
                if !lines.isEmpty { lines.append("") }
                if !host.group.isEmpty {
                    lines.append("# \(host.group)")
                }
                currentGroup = host.group
            }

            let prefix = host.isEnabled ? "" : "## "
            lines.append("\(prefix)Host \(host.hostPattern)")
            if !host.hostname.isEmpty {
                lines.append("\(prefix)    HostName \(host.hostname)")
            }
            if !host.user.isEmpty {
                lines.append("\(prefix)    User \(host.user)")
            }
            if !host.port.isEmpty && host.port != "22" {
                lines.append("\(prefix)    Port \(host.port)")
            }
            if !host.identityFile.isEmpty {
                lines.append("\(prefix)    IdentityFile \(host.identityFile)")
            }
            for directive in host.otherDirectives {
                lines.append("\(prefix)    \(directive.key) \(directive.value)")
            }
        }

        if !lines.isEmpty && !lines.last!.isEmpty {
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    static func parseHosts(from contents: String) -> [SSHHost] {
        var hosts: [SSHHost] = []
        var currentGroup = ""
        let lines = contents.components(separatedBy: .newlines)

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                i += 1
                continue
            }

            if trimmed.hasPrefix("##") {
                let uncommented = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if uncommented.lowercased().hasPrefix("host ") && !uncommented.lowercased().hasPrefix("hostname") {
                    let (host, nextIndex) = parseHostBlock(lines: lines, startIndex: i, group: currentGroup, isEnabled: false)
                    if let host { hosts.append(host) }
                    i = nextIndex
                    continue
                }
            }

            if trimmed.hasPrefix("#") && !trimmed.hasPrefix("##") {
                let candidate = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty && hasHostAfter(index: i, in: lines) {
                    currentGroup = candidate
                }
                i += 1
                continue
            }

            if trimmed.lowercased().hasPrefix("host ") && !trimmed.lowercased().hasPrefix("hostname") {
                let (host, nextIndex) = parseHostBlock(lines: lines, startIndex: i, group: currentGroup, isEnabled: true)
                if let host { hosts.append(host) }
                i = nextIndex
                continue
            }

            i += 1
        }

        return hosts
    }

    private enum DirectiveLine {
        case directive(String)
        case blockEnd
    }

    private static func classifyDirectiveLine(_ line: String, isEnabled: Bool) -> DirectiveLine {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .blockEnd }

        if trimmed.hasPrefix("##") {
            let inner = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            let lower = inner.lowercased()
            if lower.hasPrefix("host ") && !lower.hasPrefix("hostname") { return .blockEnd }
            return isEnabled ? .blockEnd : .directive(inner)
        }

        if !isEnabled { return .blockEnd }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("host ") && !lower.hasPrefix("hostname") { return .blockEnd }
        if trimmed.hasPrefix("#") { return .blockEnd }

        return .directive(trimmed)
    }

    private static func parseDirective(_ content: String) -> (key: String, value: String)? {
        let parts = content.split(separator: " ", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]).trimmingCharacters(in: .whitespaces))
    }

    private static func parseHostBlock(
        lines: [String], startIndex: Int, group: String, isEnabled: Bool
    ) -> (SSHHost?, Int) {
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let raw = isEnabled ? firstLine : String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)

        guard raw.lowercased().hasPrefix("host ") else { return (nil, startIndex + 1) }
        let pattern = String(raw.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return (nil, startIndex + 1) }

        var directives: [(key: String, value: String)] = []
        var i = startIndex + 1
        loop: while i < lines.count {
            switch classifyDirectiveLine(lines[i], isEnabled: isEnabled) {
            case .blockEnd: break loop
            case .directive(let content):
                if let pair = parseDirective(content) { directives.append(pair) }
                i += 1
            }
        }

        let mapped = Dictionary(directives.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { _, last in last })
        let others = directives.filter { !["hostname", "user", "port", "identityfile"].contains($0.key.lowercased()) }
        let host = SSHHost(
            hostPattern: pattern, hostname: mapped["hostname", default: ""],
            user: mapped["user", default: ""], port: mapped["port", default: ""],
            identityFile: mapped["identityfile", default: ""], otherDirectives: others,
            group: group, isEnabled: isEnabled
        )
        return (host, i)
    }

    private static func hasHostAfter(index: Int, in lines: [String]) -> Bool {
        for i in (index + 1)..<lines.count {
            let next = lines[i].trimmingCharacters(in: .whitespaces)
            if next.isEmpty { continue }
            let lower = next.lowercased()
            if lower.hasPrefix("host ") && !lower.hasPrefix("hostname") { return true }
            if next.hasPrefix("##") {
                let uncommented = String(next.dropFirst(2)).trimmingCharacters(in: .whitespaces).lowercased()
                if uncommented.hasPrefix("host ") && !uncommented.hasPrefix("hostname") { return true }
            }
            return false
        }
        return false
    }
}
