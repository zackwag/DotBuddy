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

    private static func parseHostBlock(lines: [String], startIndex: Int, group: String, isEnabled: Bool) -> (SSHHost?, Int) {
        let firstLine = lines[startIndex].trimmingCharacters(in: .whitespaces)
        let uncommented = isEnabled ? firstLine : String(firstLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)

        guard uncommented.lowercased().hasPrefix("host ") else {
            return (nil, startIndex + 1)
        }

        let pattern = String(uncommented.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return (nil, startIndex + 1) }

        var hostname = ""
        var user = ""
        var port = ""
        var identityFile = ""
        var otherDirectives: [(key: String, value: String)] = []

        var i = startIndex + 1
        while i < lines.count {
            let line = lines[i]
            var trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty { break }

            if trimmed.hasPrefix("##") {
                let uncommented = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                let lowerU = uncommented.lowercased()
                if lowerU.hasPrefix("host ") && !lowerU.hasPrefix("hostname") {
                    break
                }
                if !isEnabled {
                    trimmed = uncommented
                } else {
                    break
                }
            } else if !isEnabled {
                break
            }

            if trimmed.lowercased().hasPrefix("host ") && !trimmed.lowercased().hasPrefix("hostname") {
                break
            }

            if trimmed.hasPrefix("#") {
                break
            }

            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else {
                i += 1
                continue
            }

            let key = String(parts[0])
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)

            switch key.lowercased() {
            case "hostname": hostname = value
            case "user": user = value
            case "port": port = value
            case "identityfile": identityFile = value
            default: otherDirectives.append((key: key, value: value))
            }

            i += 1
        }

        let host = SSHHost(
            hostPattern: pattern,
            hostname: hostname,
            user: user,
            port: port,
            identityFile: identityFile,
            otherDirectives: otherDirectives,
            group: group,
            isEnabled: isEnabled
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
