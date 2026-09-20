import Foundation
import XCTest

@testable import DotBuddyCore

final class ParseKnownHostsTests: XCTestCase {
    func testParsesBasicEntry() {
        let input = "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl\n"
        let hosts = KnownHostsFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].hostnames, "github.com")
        XCTAssertEqual(hosts[0].keyType, "ssh-ed25519")
        XCTAssertTrue(hosts[0].publicKey.hasPrefix("AAAAC3"))
        XCTAssertFalse(hosts[0].isHashed)
    }

    func testParsesMultipleHostnames() {
        let input = "host1,host2,192.168.1.1 ssh-rsa AAAAB3key\n"
        let hosts = KnownHostsFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].hostnames, "host1,host2,192.168.1.1")
        XCTAssertEqual(hosts[0].hostnameList.count, 3)
    }

    func testDetectsHashedEntries() {
        let input = "|1|abc123|def456 ssh-ed25519 AAAAC3key\n"
        let hosts = KnownHostsFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertTrue(hosts[0].isHashed)
        XCTAssertEqual(hosts[0].displayName, "(hashed)")
    }

    func testSkipsComments() {
        let input = "# This is a comment\ngithub.com ssh-rsa AAAAB3key\n"
        let hosts = KnownHostsFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].hostnames, "github.com")
    }

    func testSkipsEmptyLines() {
        let input = "\n\ngithub.com ssh-rsa AAAAB3key\n\n"
        let hosts = KnownHostsFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 1)
    }

    func testSkipsMalformedLines() {
        let input = "not-enough-fields\ngithub.com ssh-rsa AAAAB3key\n"
        let hosts = KnownHostsFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 1)
    }

    func testParsesMultipleEntries() {
        let input = """
        github.com ssh-ed25519 AAAAC3key1
        gitlab.com ssh-rsa AAAAB3key2
        bitbucket.org ecdsa-sha2-nistp256 AAAAE2key3
        """
        let hosts = KnownHostsFileManager.parseHosts(from: input)
        XCTAssertEqual(hosts.count, 3)
        XCTAssertEqual(hosts[0].hostnames, "github.com")
        XCTAssertEqual(hosts[1].hostnames, "gitlab.com")
        XCTAssertEqual(hosts[2].hostnames, "bitbucket.org")
    }

    func testEmptyInput() {
        let hosts = KnownHostsFileManager.parseHosts(from: "")
        XCTAssertTrue(hosts.isEmpty)
    }
}

final class SerializeKnownHostsTests: XCTestCase {
    func testSerializesEntries() {
        let hosts = [
            KnownHost(hostnames: "github.com", keyType: "ssh-ed25519", publicKey: "AAAAC3key"),
            KnownHost(hostnames: "gitlab.com", keyType: "ssh-rsa", publicKey: "AAAAB3key"),
        ]
        let output = KnownHostsFileManager.serialize(hosts: hosts)
        XCTAssertTrue(output.contains("github.com ssh-ed25519 AAAAC3key"))
        XCTAssertTrue(output.contains("gitlab.com ssh-rsa AAAAB3key"))
    }

    func testRoundTrip() {
        let original = [
            KnownHost(hostnames: "github.com", keyType: "ssh-ed25519", publicKey: "AAAAC3key1"),
            KnownHost(hostnames: "host1,host2", keyType: "ssh-rsa", publicKey: "AAAAB3key2"),
            KnownHost(hostnames: "|1|hash1|hash2", keyType: "ecdsa-sha2-nistp256", publicKey: "AAAAE2key3", isHashed: true),
        ]
        let serialized = KnownHostsFileManager.serialize(hosts: original)
        let parsed = KnownHostsFileManager.parseHosts(from: serialized)
        XCTAssertEqual(parsed.count, original.count)
        for (a, b) in zip(parsed, original) {
            XCTAssertEqual(a.hostnames, b.hostnames)
            XCTAssertEqual(a.keyType, b.keyType)
            XCTAssertEqual(a.publicKey, b.publicKey)
            XCTAssertEqual(a.isHashed, b.isHashed)
        }
    }
}

final class KnownHostsFileManagerIOTests: XCTestCase {
    var tempDir: String!

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory() + "dotbuddy-kh-test-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        let path = tempDir + "/known_hosts"
        let manager = KnownHostsFileManager(path: path)
        let hosts = [KnownHost(hostnames: "test.com", keyType: "ssh-rsa", publicKey: "AAAAB3key")]
        try manager.save(hosts)
        let loaded = try manager.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].hostnames, "test.com")
    }

    func testSaveCreatesBackup() throws {
        let path = tempDir + "/known_hosts"
        let manager = KnownHostsFileManager(path: path)
        try manager.save([KnownHost(hostnames: "v1.com", keyType: "ssh-rsa", publicKey: "key1")])
        try manager.save([KnownHost(hostnames: "v2.com", keyType: "ssh-rsa", publicKey: "key2")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: path + ".bak"))
        let backup = try String(contentsOfFile: path + ".bak", encoding: .utf8)
        XCTAssertTrue(backup.contains("v1.com"))
    }

    func testLoadNonexistentReturnsEmpty() throws {
        let manager = KnownHostsFileManager(path: tempDir + "/nonexistent")
        let hosts = try manager.load()
        XCTAssertTrue(hosts.isEmpty)
    }
}
