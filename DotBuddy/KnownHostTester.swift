import Foundation

struct KnownHostTestResult: Identifiable {
    let id: UUID
    let hostname: String
    let status: SSHConnectionStatus
}

enum KnownHostTester {
    struct HostTarget: Sendable {
        let hostname: String
        let port: String

        init(raw: String) {
            if raw.hasPrefix("["), let closeBracket = raw.firstIndex(of: "]") {
                hostname = String(raw[raw.index(after: raw.startIndex)..<closeBracket])
                let after = raw[raw.index(after: closeBracket)...]
                if after.hasPrefix(":") {
                    port = String(after.dropFirst())
                } else {
                    port = "22"
                }
            } else {
                hostname = raw
                port = "22"
            }
        }
    }

    nonisolated static func test(target: HostTarget) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
        process.arguments = ["-z", "-w", "5", target.hostname, target.port]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return false
        }

        return process.terminationStatus == 0
    }
}
