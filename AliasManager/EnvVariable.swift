import Foundation

struct EnvVariable: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var value: String
    var group: String
    var isSecret: Bool

    init(id: UUID = UUID(), name: String, value: String, group: String = "", isSecret: Bool = false) {
        self.id = id
        self.name = name
        self.value = value
        self.group = group
        self.isSecret = isSecret
    }
}
