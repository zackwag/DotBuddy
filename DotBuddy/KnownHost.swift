import Foundation

struct KnownHost: Identifiable, Equatable, Hashable {
    let id: UUID
    var hostnames: String
    var keyType: String
    var publicKey: String
    var isHashed: Bool

    init(
        id: UUID = UUID(),
        hostnames: String,
        keyType: String,
        publicKey: String,
        isHashed: Bool = false
    ) {
        self.id = id
        self.hostnames = hostnames
        self.keyType = keyType
        self.publicKey = publicKey
        self.isHashed = isHashed
    }

    var displayName: String {
        if isHashed {
            return "(hashed)"
        }
        return hostnames
    }

    var hostnameList: [String] {
        hostnames.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    var truncatedKey: String {
        if publicKey.count > 40 {
            return String(publicKey.prefix(20)) + "..." + String(publicKey.suffix(16))
        }
        return publicKey
    }
}
