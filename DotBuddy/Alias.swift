import Foundation

enum SortOrder: Int {
    case none = 0, ascending = 1, descending = 2

    var systemImage: String {
        switch self {
        case .none: return "arrow.up.arrow.down"
        case .ascending: return "arrow.up"
        case .descending: return "arrow.down"
        }
    }

    mutating func toggle() {
        switch self {
        case .none: self = .ascending
        case .ascending: self = .descending
        case .descending: self = .none
        }
    }
}

struct Alias: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var command: String
    var group: String
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, command: String, group: String = "", isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.command = command
        self.group = group
        self.isEnabled = isEnabled
    }
}
