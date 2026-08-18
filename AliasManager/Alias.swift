import Foundation

struct Alias: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var command: String
    var group: String

    init(id: UUID = UUID(), name: String, command: String, group: String = "") {
        self.id = id
        self.name = name
        self.command = command
        self.group = group
    }
}
