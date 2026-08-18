import Foundation
import SwiftUI

@MainActor
final class AliasViewModel: ObservableObject {
    @Published var aliases: [Alias] = []
    @Published var workingAliases: [Alias] = []
    @Published var searchText: String = ""
    @Published var sortOrder: SortOrder = .none
    private var preSortOrder: [Alias]?
    @Published var filePath: String?
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSourceReminder = false

    private static let filePathKey = "aliasFilePath"
    private static let sortOrderKey = "aliasSortOrder"
    private static let suppressReminderKey = "suppressSourceReminder"

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

    var hasUnsavedChanges: Bool {
        aliases != workingAliases
    }

    var hasFile: Bool {
        filePath != nil
    }

    var fileName: String {
        guard let filePath else { return "No file selected" }
        return (filePath as NSString).lastPathComponent
    }

    var sourceCommand: String {
        guard let filePath else { return "" }
        if filePath.contains(" ") {
            return "source \"\(filePath)\""
        }
        return "source \(filePath)"
    }

    var groups: [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for alias in workingAliases {
            if !alias.group.isEmpty && seen.insert(alias.group).inserted {
                result.append(alias.group)
            }
        }
        return result
    }

    var groupedAliases: [(group: String, aliases: [Alias])] {
        let filtered = displayedAliases
        var order: [String] = []
        var grouped: [String: [Alias]] = [:]

        for alias in filtered {
            if grouped[alias.group] == nil {
                order.append(alias.group)
            }
            grouped[alias.group, default: []].append(alias)
        }

        return order.map { (group: $0, aliases: grouped[$0]!) }
    }

    var displayedAliases: [Alias] {
        var result = workingAliases

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.command.lowercased().contains(query) ||
                $0.group.lowercased().contains(query)
            }
        }

        return result
    }

    func applySort() {
        UserDefaults.standard.set(sortOrder.rawValue, forKey: Self.sortOrderKey)

        if sortOrder == .none {
            if let original = preSortOrder {
                workingAliases = original
                preSortOrder = nil
            }
            return
        }

        if preSortOrder == nil {
            preSortOrder = workingAliases
        }

        var groupOrder: [String] = []
        var grouped: [String: [Alias]] = [:]

        for alias in workingAliases {
            if grouped[alias.group] == nil {
                groupOrder.append(alias.group)
            }
            grouped[alias.group, default: []].append(alias)
        }

        let ascending = sortOrder == .ascending
        let comparator: (String, String) -> ComparisonResult = { $0.localizedCaseInsensitiveCompare($1) }

        groupOrder.sort { a, b in
            if a.isEmpty { return !ascending }
            if b.isEmpty { return ascending }
            return ascending
                ? comparator(a, b) == .orderedAscending
                : comparator(a, b) == .orderedDescending
        }

        let aliasComparator: (Alias, Alias) -> Bool = ascending
            ? { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            : { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }

        workingAliases = groupOrder.flatMap { group in
            grouped[group]!.sorted(by: aliasComparator)
        }
    }

    init() {
        filePath = UserDefaults.standard.string(forKey: Self.filePathKey)
        let rawSort = UserDefaults.standard.integer(forKey: Self.sortOrderKey)
        sortOrder = SortOrder(rawValue: rawSort) ?? .none
    }

    func selectFile(url: URL) {
        let path = url.path
        filePath = path
        UserDefaults.standard.set(path, forKey: Self.filePathKey)
        loadAliases()
    }

    func createDefault() {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".aliases.zsh").path
        FileManager.default.createFile(atPath: path, contents: nil)
        filePath = path
        UserDefaults.standard.set(path, forKey: Self.filePathKey)
        aliases = []
        workingAliases = []
    }

    func loadAliases() {
        guard let filePath else { return }
        do {
            let manager = AliasFileManager(path: filePath)
            aliases = try manager.load()
            workingAliases = aliases
            if sortOrder != .none {
                applySort()
            }
        } catch {
            showError(message: "Failed to load aliases: \(error.localizedDescription)")
        }
    }

    func addAlias(name: String, command: String, group: String) -> Bool {
        guard !name.isEmpty, !command.isEmpty else { return false }

        if workingAliases.contains(where: { $0.name == name }) {
            showError(message: "An alias named '\(name)' already exists.")
            return false
        }

        let newAlias = Alias(name: name, command: command, group: group)

        if group.isEmpty {
            workingAliases.append(newAlias)
        } else if let lastIndex = workingAliases.lastIndex(where: { $0.group == group }) {
            workingAliases.insert(newAlias, at: workingAliases.index(after: lastIndex))
        } else {
            workingAliases.append(newAlias)
        }

        if sortOrder != .none {
            applySort()
        }

        return true
    }

    func updateAlias(id: UUID, name: String, command: String, group: String) -> Bool {
        guard !name.isEmpty, !command.isEmpty else { return false }

        if workingAliases.contains(where: { $0.name == name && $0.id != id }) {
            showError(message: "An alias named '\(name)' already exists.")
            return false
        }

        guard let index = workingAliases.firstIndex(where: { $0.id == id }) else { return false }
        workingAliases[index] = Alias(id: id, name: name, command: command, group: group)
        return true
    }

    func renameGroup(from oldName: String, to newName: String) {
        for index in workingAliases.indices {
            if workingAliases[index].group == oldName {
                workingAliases[index].group = newName
            }
        }
    }

    func moveAliases(in group: String, from source: IndexSet, to destination: Int) {
        var groupAliases = workingAliases.filter { $0.group == group }
        groupAliases.move(fromOffsets: source, toOffset: destination)

        var result: [Alias] = []
        var groupInserted = false
        for alias in workingAliases {
            if alias.group == group {
                if !groupInserted {
                    result.append(contentsOf: groupAliases)
                    groupInserted = true
                }
            } else {
                result.append(alias)
            }
        }
        if !groupInserted {
            result.append(contentsOf: groupAliases)
        }

        workingAliases = result
    }

    func deleteAlias(_ alias: Alias) {
        workingAliases.removeAll { $0.id == alias.id }
    }

    func deleteAliases(at offsets: IndexSet) {
        let displayed = displayedAliases
        let idsToRemove = offsets.map { displayed[$0].id }
        workingAliases.removeAll { idsToRemove.contains($0.id) }
    }

    func saveChanges() {
        guard let filePath else { return }
        do {
            aliases = workingAliases
            preSortOrder = nil
            let manager = AliasFileManager(path: filePath)
            try manager.save(aliases)
            if !UserDefaults.standard.bool(forKey: Self.suppressReminderKey) {
                showSourceReminder = true
            }
        } catch {
            showError(message: "Failed to save aliases: \(error.localizedDescription)")
        }
    }

    func suppressReminder() {
        UserDefaults.standard.set(true, forKey: Self.suppressReminderKey)
    }

    func discardChanges() {
        workingAliases = aliases
    }

    func importAliases(from url: URL) -> Int {
        do {
            let imported = try AliasFileManager.loadAliases(from: url)
            guard !imported.isEmpty else {
                showError(message: "No aliases found in the selected file.")
                return 0
            }

            var addedCount = 0
            for alias in imported {
                if !workingAliases.contains(where: { $0.name == alias.name }) {
                    workingAliases.append(alias)
                    addedCount += 1
                }
            }

            if addedCount == 0 {
                showError(message: "All \(imported.count) aliases in the file already exist. No new aliases imported.")
            }

            return addedCount
        } catch {
            showError(message: "Failed to import file: \(error.localizedDescription)")
            return 0
        }
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}
