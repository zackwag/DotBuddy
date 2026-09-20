import Foundation
import XCTest

@testable import DotBuddyCore

final class ParseSSHConfigTests: XCTestCase {
    func testParsesBasicHost() {
        let input = """
        Host myserver
            HostName 192.168.1.1
            User admin
            Port 2222
            IdentityFile ~/.ssh/id_rsa
        """
        let hosts = SSHConfigFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].hostPattern, "myserver")
        XCTAssertEqual(hosts[0].hostname, "192.168.1.1")
        XCTAssertEqual(hosts[0].user, "admin")
        XCTAssertEqual(hosts[0].port, "2222")
        XCTAssertEqual(hosts[0].identityFile, "~/.ssh/id_rsa")
        XCTAssertTrue(hosts[0].isEnabled)
    }

    func testParsesHostWithoutOptionalFields() {
        let input = "Host jumpbox\n    HostName jump.example.com\n"
        let hosts = SSHConfigFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].hostPattern, "jumpbox")
        XCTAssertEqual(hosts[0].hostname, "jump.example.com")
        XCTAssertEqual(hosts[0].user, "")
        XCTAssertEqual(hosts[0].port, "")
        XCTAssertEqual(hosts[0].identityFile, "")
    }

    func testParsesMultipleHosts() {
        let input = """
        Host server1
            HostName 10.0.0.1

        Host server2
            HostName 10.0.0.2
        """
        let hosts = SSHConfigFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 2)
        XCTAssertEqual(hosts[0].hostPattern, "server1")
        XCTAssertEqual(hosts[1].hostPattern, "server2")
    }

    func testParsesDisabledHost() {
        let input = """
        ## Host oldserver
        ##     HostName old.example.com
        ##     User deploy
        """
        let hosts = SSHConfigFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].hostPattern, "oldserver")
        XCTAssertEqual(hosts[0].hostname, "old.example.com")
        XCTAssertEqual(hosts[0].user, "deploy")
        XCTAssertFalse(hosts[0].isEnabled)
    }

    func testParsesGroups() {
        let input = """
        # Production
        Host prod
            HostName prod.example.com

        # Staging
        Host staging
            HostName staging.example.com
        """
        let hosts = SSHConfigFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 2)
        XCTAssertEqual(hosts[0].group, "Production")
        XCTAssertEqual(hosts[1].group, "Staging")
    }

    func testParsesOtherDirectives() {
        let input = """
        Host myserver
            HostName 192.168.1.1
            ForwardAgent yes
            ProxyJump bastion
        """
        let hosts = SSHConfigFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].otherDirectives.count, 2)
        XCTAssertEqual(hosts[0].otherDirectives[0].key, "ForwardAgent")
        XCTAssertEqual(hosts[0].otherDirectives[0].value, "yes")
        XCTAssertEqual(hosts[0].otherDirectives[1].key, "ProxyJump")
        XCTAssertEqual(hosts[0].otherDirectives[1].value, "bastion")
    }

    func testParsesWildcardHost() {
        let input = "Host *\n    ServerAliveInterval 60\n"
        let hosts = SSHConfigFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].hostPattern, "*")
    }

    func testSkipsEmptyInput() {
        let hosts = SSHConfigFileManager.parseHosts(from: "")
        XCTAssertTrue(hosts.isEmpty)
    }

    func testSkipsCommentOnlyInput() {
        let hosts = SSHConfigFileManager.parseHosts(from: "# Just a comment\n")
        XCTAssertTrue(hosts.isEmpty)
    }
}

final class SerializeSSHConfigTests: XCTestCase {
    func testSerializesBasicHost() {
        let host = SSHHost(
            hostPattern: "myserver",
            hostname: "192.168.1.1",
            user: "admin",
            port: "2222",
            identityFile: "~/.ssh/id_rsa"
        )
        let output = SSHConfigFileManager.serialize(hosts: [host])
        XCTAssertTrue(output.contains("Host myserver"))
        XCTAssertTrue(output.contains("    HostName 192.168.1.1"))
        XCTAssertTrue(output.contains("    User admin"))
        XCTAssertTrue(output.contains("    Port 2222"))
        XCTAssertTrue(output.contains("    IdentityFile ~/.ssh/id_rsa"))
    }

    func testSerializesDisabledHost() {
        let host = SSHHost(hostPattern: "old", hostname: "old.example.com", isEnabled: false)
        let output = SSHConfigFileManager.serialize(hosts: [host])
        XCTAssertTrue(output.contains("## Host old"))
        XCTAssertTrue(output.contains("##     HostName old.example.com"))
    }

    func testSkipsDefaultPort() {
        let host = SSHHost(hostPattern: "test", hostname: "test.com", port: "22")
        let output = SSHConfigFileManager.serialize(hosts: [host])
        XCTAssertFalse(output.contains("Port"))
    }

    func testSerializesGroups() {
        let hosts = [
            SSHHost(hostPattern: "prod", hostname: "prod.com", group: "Production"),
            SSHHost(hostPattern: "staging", hostname: "staging.com", group: "Staging"),
        ]
        let output = SSHConfigFileManager.serialize(hosts: hosts)
        XCTAssertTrue(output.contains("# Production"))
        XCTAssertTrue(output.contains("# Staging"))
    }

    func testSerializesOtherDirectives() {
        let host = SSHHost(
            hostPattern: "test",
            hostname: "test.com",
            otherDirectives: [("ForwardAgent", "yes")]
        )
        let output = SSHConfigFileManager.serialize(hosts: [host])
        XCTAssertTrue(output.contains("    ForwardAgent yes"))
    }

    func testRoundTrip() {
        let original = [
            SSHHost(hostPattern: "prod", hostname: "10.0.0.1", user: "deploy", port: "2222", identityFile: "~/.ssh/prod", group: "Production"),
            SSHHost(hostPattern: "staging", hostname: "10.0.0.2", user: "admin", group: "Staging"),
            SSHHost(hostPattern: "disabled", hostname: "old.com", group: "Staging", isEnabled: false),
        ]
        let serialized = SSHConfigFileManager.serialize(hosts: original)
        let parsed = SSHConfigFileManager.parseHosts(from: serialized)
        XCTAssertEqual(parsed.count, original.count)
        for (a, b) in zip(parsed, original) {
            XCTAssertEqual(a.hostPattern, b.hostPattern)
            XCTAssertEqual(a.hostname, b.hostname)
            XCTAssertEqual(a.user, b.user)
            XCTAssertEqual(a.port, b.port)
            XCTAssertEqual(a.identityFile, b.identityFile)
            XCTAssertEqual(a.group, b.group)
            XCTAssertEqual(a.isEnabled, b.isEnabled)
        }
    }
}

final class SSHConfigFileManagerIOTests: XCTestCase {
    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory() + "dotbuddy-ssh-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        let path = tempDir + "/config"
        let manager = SSHConfigFileManager(path: path)
        let hosts = [
            SSHHost(hostPattern: "test", hostname: "test.com", user: "root"),
        ]
        try manager.save(hosts)
        let loaded = try manager.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].hostPattern, "test")
        XCTAssertEqual(loaded[0].hostname, "test.com")
    }

    func testSaveCreatesBackup() throws {
        let path = tempDir + "/config"
        let manager = SSHConfigFileManager(path: path)
        try manager.save([SSHHost(hostPattern: "v1", hostname: "v1.com")])
        try manager.save([SSHHost(hostPattern: "v2", hostname: "v2.com")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: path + ".bak"))
        let backup = try String(contentsOfFile: path + ".bak", encoding: .utf8)
        XCTAssertTrue(backup.contains("v1"))
    }

    func testLoadNonexistentReturnsEmpty() throws {
        let manager = SSHConfigFileManager(path: tempDir + "/nonexistent")
        let hosts = try manager.load()
        XCTAssertTrue(hosts.isEmpty)
    }
}
