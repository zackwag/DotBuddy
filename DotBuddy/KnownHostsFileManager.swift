import Foundation

struct KnownHostsFileManager {
    let path: String

    func load() throws -> [KnownHost] {
        guard FileManager.default.fileExists(atPath: path) else {
            return []
        }
        let contents = try String(contentsOfFile: path, encoding: .utf8)
        return Self.parseHosts(from: contents)
    }

    func save(_ hosts: [KnownHost]) throws {
        if FileManager.default.fileExists(atPath: path) {
            let backupPath = path + ".bak"
            try? FileManager.default.removeItem(atPath: backupPath)
            try? FileManager.default.copyItem(atPath: path, toPath: backupPath)
        }
        let content = Self.serialize(hosts: hosts)
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func serialize(hosts: [KnownHost]) -> String {
        let lines = hosts.map { host in
            "\(host.hostnames) \(host.keyType) \(host.publicKey)"
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func parseHosts(from contents: String) -> [KnownHost] {
        var hosts: [KnownHost] = []
        let lines = contents.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 2)
            guard parts.count == 3 else { continue }

            let hostnames = String(parts[0])
            let keyType = String(parts[1])
            let publicKey = String(parts[2])
            let isHashed = hostnames.hasPrefix("|1|")

            hosts.append(KnownHost(
                hostnames: hostnames,
                keyType: keyType,
                publicKey: publicKey,
                isHashed: isHashed
            ))
        }

        return hosts
    }
}
