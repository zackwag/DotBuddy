import Foundation

enum SSHConnectionStatus: Equatable {
    case idle
    case testing
    case success
    case failure
}

struct SSHConnectionResult: Identifiable {
    let id: UUID
    let hostPattern: String
    let status: SSHConnectionStatus
}

enum SSHConnectionTester {
    struct TestConfig: Sendable {
        let hostPattern: String
    }

    nonisolated static func test(config: TestConfig) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-o", "ConnectTimeout=5",
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=no",
            config.hostPattern,
            "exit"
        ]
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
