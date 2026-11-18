import Foundation

struct GitConfigEntry: Identifiable, Equatable, Hashable {
    let id: UUID
    /// Raw header text between the brackets, e.g. `user` or `remote "origin"`.
    var section: String
    var key: String
    var value: String

    init(id: UUID = UUID(), section: String, key: String, value: String) {
        self.id = id
        self.section = section
        self.key = key
        self.value = value
    }
}
