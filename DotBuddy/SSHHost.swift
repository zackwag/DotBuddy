import Foundation

struct SSHHost: Identifiable, Equatable, Hashable {
    let id: UUID
    var hostPattern: String
    var hostname: String
    var user: String
    var port: String
    var identityFile: String
    var otherDirectives: [(key: String, value: String)]
    var group: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        hostPattern: String,
        hostname: String = "",
        user: String = "",
        port: String = "",
        identityFile: String = "",
        otherDirectives: [(key: String, value: String)] = [],
        group: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.hostPattern = hostPattern
        self.hostname = hostname
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.otherDirectives = otherDirectives
        self.group = group
        self.isEnabled = isEnabled
    }

    var displayHostname: String {
        hostname.isEmpty ? hostPattern : hostname
    }

    var summary: String {
        var parts: [String] = []
        if !user.isEmpty { parts.append(user + "@") }
        parts.append(hostname.isEmpty ? hostPattern : hostname)
        if !port.isEmpty && port != "22" { parts.append(":\(port)") }
        return parts.joined()
    }

    static func == (lhs: SSHHost, rhs: SSHHost) -> Bool {
        lhs.id == rhs.id &&
        lhs.hostPattern == rhs.hostPattern &&
        lhs.hostname == rhs.hostname &&
        lhs.user == rhs.user &&
        lhs.port == rhs.port &&
        lhs.identityFile == rhs.identityFile &&
        lhs.group == rhs.group &&
        lhs.isEnabled == rhs.isEnabled &&
        lhs.otherDirectives.count == rhs.otherDirectives.count &&
        zip(lhs.otherDirectives, rhs.otherDirectives).allSatisfy { $0.key == $1.key && $0.value == $1.value }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(hostPattern)
        hasher.combine(hostname)
        hasher.combine(user)
        hasher.combine(port)
        hasher.combine(identityFile)
        hasher.combine(group)
        hasher.combine(isEnabled)
    }
}
